#!/bin/bash
# Prometheus storage cleanup helper
# Use this when Prometheus storage is filling up or after alerts fire
#
# Prerequisites:
#   - kubectl access to the cluster
#   - Port-forward or in-cluster access to Prometheus API
#
# Usage:
#   ./scripts/cleanup-prometheus.sh [command]
#
# Commands:
#   status    - Show current storage usage (default)
#   delete    - Delete old series (interactive, asks for time range)
#   compact   - Clean tombstones after deletion
#   host      - Check host-level disk and qcow2 usage
#   all       - Run status + host checks

set -e

PROMETHEUS_POD="prometheus-kube-prometheus-stack-prometheus-0"
PROMETHEUS_NS="monitoring"
PROMETHEUS_PORT=9090

command="${1:-status}"

# Helper: port-forward to Prometheus if not already forwarded
prom_curl() {
    kubectl exec -n "$PROMETHEUS_NS" "$PROMETHEUS_POD" -- \
        wget -q -O - "http://localhost:$PROMETHEUS_PORT$1" 2>/dev/null
}

case "$command" in
    status)
        echo "=== Prometheus Storage Status ==="
        echo ""
        echo "PVC usage:"
        kubectl exec -n "$PROMETHEUS_NS" "$PROMETHEUS_POD" -- df -h /prometheus 2>/dev/null || \
            echo "  (Could not exec into pod — is Prometheus running?)"
        echo ""
        echo "TSDB status:"
        prom_curl "/api/v1/status/tsdb" 2>/dev/null | head -c 500 || \
            echo "  (Could not query TSDB status)"
        echo ""
        echo "Retention config:"
        prom_curl "/api/v1/status/flags" 2>/dev/null | grep -o '"storage[^"]*":"[^"]*"' || \
            echo "  (Could not query flags)"
        echo ""
        echo "PVC details:"
        kubectl get pvc -n "$PROMETHEUS_NS" -l app.kubernetes.io/name=prometheus
        ;;

    delete)
        echo "=== Delete Old Prometheus Series ==="
        echo ""
        echo "WARNING: This will permanently delete metric data."
        echo ""
        read -rp "Delete data older than how many days? [default: 3]: " days
        days="${days:-3}"

        end_time=$(date -u -d "$days days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
                   date -u -v-"${days}d" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)

        echo ""
        echo "Will delete all series data before: $end_time"
        read -rp "Continue? [y/N]: " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Aborted."
            exit 0
        fi

        echo "Deleting series..."
        kubectl exec -n "$PROMETHEUS_NS" "$PROMETHEUS_POD" -- \
            wget -q -O - --post-data="match[]={__name__=~\".+\"}&end=$end_time" \
            "http://localhost:$PROMETHEUS_PORT/api/v1/admin/tsdb/delete_series"

        echo ""
        echo "Cleaning tombstones (this reclaims disk space)..."
        kubectl exec -n "$PROMETHEUS_NS" "$PROMETHEUS_POD" -- \
            wget -q -O - --post-data="" \
            "http://localhost:$PROMETHEUS_PORT/api/v1/admin/tsdb/clean_tombstones"

        echo ""
        echo "✓ Cleanup complete. Check storage with: $0 status"
        ;;

    compact)
        echo "=== Clean Tombstones ==="
        echo "This reclaims disk space after series deletion."
        echo ""
        kubectl exec -n "$PROMETHEUS_NS" "$PROMETHEUS_POD" -- \
            wget -q -O - --post-data="" \
            "http://localhost:$PROMETHEUS_PORT/api/v1/admin/tsdb/clean_tombstones"
        echo ""
        echo "✓ Tombstones cleaned."
        ;;

    host)
        echo "=== Host Storage Status ==="
        echo ""
        echo "Host filesystem:"
        echo "  (Run on host: df -h /mnt/persistent)"
        echo ""
        echo "qcow2 disk images (actual vs allocated):"
        echo "  (Run on host: sudo qemu-img info /mnt/persistent/disks/*.qcow2)"
        echo ""
        echo "Talos persistent mount:"
        talosctl -n 192.168.1.222 mounts 2>/dev/null | grep persistent || \
            echo "  (Could not query Talos mounts)"
        echo ""
        echo "Local-path-provisioner directories:"
        talosctl -n 192.168.1.222 ls /var/lib/persistent/local-path-provisioner/ 2>/dev/null || \
            echo "  (Could not list directories)"
        ;;

    all)
        "$0" status
        echo ""
        echo "---"
        echo ""
        "$0" host
        ;;

    *)
        echo "Usage: $0 {status|delete|compact|host|all}"
        echo ""
        echo "Commands:"
        echo "  status  - Show Prometheus storage usage (default)"
        echo "  delete  - Delete old series (interactive)"
        echo "  compact - Clean tombstones to reclaim space"
        echo "  host    - Check host-level disk usage"
        echo "  all     - Run status + host checks"
        exit 1
        ;;
esac
