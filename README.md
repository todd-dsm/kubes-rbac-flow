# kubes-rbac-flow
A quick and dirty Kubernetes RBAC flow. To see this in action:

1) install minikube: `brew install minikube`

2) Run the script with an argument of a username:

`./10-generate-rbac-user-cert.sh mvh 2>&1 | tee /tmp/kubes-rbac.out`

This will generate certs and:

  * Create a user
  * Assign authentication credentials
  * Deploy a Role (like Group Permissions)
  * Deploy a RoleBinding (like adding a user to a group)
  * Drops a log: `/tmp/kubes-rbac.out` for review.

`set -x` is on so all the gory details are displayed.

When done, run the clean-up script to remove excess jive.

`./cleanup.sh mvh`