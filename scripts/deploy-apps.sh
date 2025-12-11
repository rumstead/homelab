#!/bin/bash
helm upgrade cilium cilium   --namespace kube-system   --set ipam.mode=kubernetes   --set kubeProxyReplacement=true   --set k8sServiceHost=192.168.1.10   --set k8sServicePort=6443   --set gatewayAPI.enabled=true   --set l2announcements.enabled=true   --set externalIPs.enabled=true   --set devices[0]="enp+"   --set devices[1]="eth+"   --set securityContext.capabilities.ciliumAgent[0]=CHOWN   --set securityContext.capabilities.ciliumAgent[1]=KILL   --set securityContext.capabilities.ciliumAgent[2]=NET_ADMIN   --set securityContext.capabilities.ciliumAgent[3]=NET_RAW   --set securityContext.capabilities.ciliumAgent[4]=IPC_LOCK   --set securityContext.capabilities.ciliumAgent[5]=SYS_ADMIN   --set securityContext.capabilities.ciliumAgent[6]=SYS_RESOURCE   --set securityContext.capabilities.ciliumAgent[7]=DAC_OVERRIDE   --set securityContext.capabilities.ciliumAgent[8]=FOWNER   --set securityContext.capabilities.ciliumAgent[9]=SETGID   --set securityContext.capabilities.ciliumAgent[10]=SETUID   --set securityContext.capabilities.cleanCiliumState[0]=NET_ADMIN   --set securityContext.capabilities.cleanCiliumState[1]=SYS_ADMIN   --set securityContext.capabilities.cleanCiliumState[2]=SYS_RESOURCE   --set cgroup.autoMount.enabled=false   --set cgroup.hostRoot=/sys/fs/cgroup   --repo https://helm.cilium.io/
kubectl apply -k bootstrap/argocd/
kubectl apply -f kubernetes/argocd-apps/argocd/app-of-apps.yaml 
kubectl apply -f kubernetes/argocd-apps/argocd/argocd-app.yaml 

ns="argocd"
port=8080
kubectl port-forward -n "$ns" service/argocd-server "$port":80 2>&1 > /dev/null &
sleep 3

# setup new password for argocd
argo_host=localhost:${port}
initial_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

argocd login ${argo_host} \
--username admin \
--password "${initial_password}" \
--insecure
argocd account update-password \
--account admin \
--current-password "${initial_password}" \
--new-password admin1234