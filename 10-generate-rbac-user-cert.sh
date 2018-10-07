#!/usr/bin/env bash
# shellcheck disable=SC2002
#  PURPOSE: Generate an X.509 certificate for Kubernetes RBAC users.
# -----------------------------------------------------------------------------
#  PREREQS: a)
#           b)
#           c)
# -----------------------------------------------------------------------------
#  EXECUTE:
# -----------------------------------------------------------------------------
#     TODO: 1)
#           2)
#           3)
# -----------------------------------------------------------------------------
#   AUTHOR: Todd E Thomas
# -----------------------------------------------------------------------------
#  CREATED: 2018/09/00
# -----------------------------------------------------------------------------
set -x


###----------------------------------------------------------------------------
### VARIABLES
###----------------------------------------------------------------------------
# ENV Stuff
reqdUser="$1"
# Data Files
userRBACFile="$reqdUser-signing-request.yaml"
userRoleBind="$reqdUser-role-binding.yaml"
userKey="$reqdUser.key"
userCSR="$reqdUser.csr"
userCert="$reqdUser.crt"


###----------------------------------------------------------------------------
### FUNCTIONS
###----------------------------------------------------------------------------


###----------------------------------------------------------------------------
### MAIN PROGRAM
###----------------------------------------------------------------------------
### Check arguments
###---
if [[ -z "$1" ]]; then
    echo "You need to pass a user as \$1; I'm out."
    exit 1
fi

###---
### Create a private key for a User
###---
openssl genrsa -out "$userKey" 2048


###---
### Create Certificate Signing Request for User key
###---
openssl req -new \
    -key "$userKey" \
    -out "$userCSR" \
    -subj "/CN=$reqdUser/O=myCompany"'\n'


###---
### REQ
###---
cat << EOF > "$userRBACFile"
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: "$userCSR"
spec:
  groups:
  - system:authenticated
  request: "$(cat "$userCSR" | base64 | tr -d '\n')"
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF



###---
### Generate a CSR (Certificate Signing Request); results in state 'Pending'
### Result: kubectl get csr: CONDITION='Pending' for user
###---
kubectl create -f "$userRBACFile"


###---
### Approve the request
### Result: kubectl get csr: CONDITION='Approved,Issued' for user
###---
kubectl certificate approve "$userCSR"


###---
### Pull the user's auth cert back from Kubernetes
###---
kubectl get csr "$userCSR" -o jsonpath='{.status.certificate}' | \
    base64 --decode > "$userCert"


###---
### Create user and assign auth credentials
###---
kubectl config set-credentials "$reqdUser" \
    --client-certificate="$userCert" --client-key="$userKey"


###---
### Set context to a  user
### Default context is 'minikube' (admin) -> user
###---
kubectl config set-context "$reqdUser-context" \
    --cluster=minikube --namespace=default --user="$reqdUser"


###---
### Output contexts
###---
kubectl config view contexts \
    -o jsonpath='{range .contexts[*]}{.name}{"\n"}{end}'


###----------------------------------------------------------------------------
### At this point, user AuthN has been configured. However, AuthZ is still yet
### to be configured; if the user attempted to "get", "watch" or "list" a
### resource, Kubernetes would error with, "user does not have access".
###----------------------------------------------------------------------------
### Deploy a generic RO (read-only) Role for unprivileged users
### Role: pod-reader
###---
# Search for the role
roleRODefault="$(kubectl get role pod-reader -o jsonpath='{.metadata.name}')"
# Deploy if it hasn't been yet
if [[ "$roleRODefault" != 'pod-reader' ]]; then
    kubectl create -f role-pods-ro-default-ns.yaml
fi


###---
### Assign a User to a Role with a 'RoleBinding'
###---
cat << EOF > "$userRoleBind"
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: "$reqdUser"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  # 'kind' must be 'Role' or 'ClusterRole'
  kind: Role
  # 'name' must match the name of the Role or ClusterRole with which to bind
  # REF: role-pods-ro-default-ns.yaml
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF


###---
### Deploy the RoleBinding for the user
###---
kubectl create -f "$userRoleBind"


###---
### REQ
###---


###---
### fin~
###---
exit 0
