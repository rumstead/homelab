## ADDED Requirements

### Requirement: Operator Install
The cluster SHALL run the Tailscale Kubernetes operator from Argo CD Application `tailscale-operator`, installing chart `tailscale-operator` version `1.104.1` from `https://pkgs.tailscale.com/helmcharts` into namespace `tailscale`.

#### Scenario: Operator joins the tailnet
- **WHEN** the Application is synced
- **THEN** a device named `tailscale-operator` tagged `tag:k8s-operator` SHALL appear in the tailnet

### Requirement: OAuth Credentials
The operator's OAuth client ID and secret SHALL be stored in git only as `kubernetes/manifests/tailscale/operator-oauth.sops.yaml`, rendered by KSOPS into Secret `operator-oauth` with keys `client_id` and `client_secret`.

#### Scenario: Credentials at rest
- **WHEN** the manifests are committed
- **THEN** the client ID and secret SHALL appear only in encrypted form

#### Scenario: Credentials do not expire
- **WHEN** 180 days have passed since the operator joined
- **THEN** the operator SHALL keep authenticating without a manual step

### Requirement: Tailnet Only Exposure
A cluster Service SHALL be reachable through Tailscale only from tailnet devices, through an Ingress with `ingressClassName: tailscale` and HTTPS on its `ts.net` name. Funnel SHALL NOT be enabled.

#### Scenario: Device on the tailnet
- **WHEN** a tailnet device opens `https://<name>.<tailnet>.ts.net`
- **THEN** it SHALL get the service over a valid certificate

#### Scenario: Device off the tailnet
- **WHEN** a device that is not on the tailnet opens the same name
- **THEN** the service SHALL NOT be reachable

### Requirement: Proxy Pod Security
The `tailscale` namespace SHALL carry `pod-security.kubernetes.io/enforce`, `audit`, and `warn` labels set to `privileged`.

#### Scenario: Proxy created
- **WHEN** an Ingress with `ingressClassName: tailscale` is created
- **THEN** its proxy pod SHALL be admitted and reach Running
