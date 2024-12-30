This repository packages a sample application `WAR` and the `IBM MQ 9.3.0.2` resource adapter archive along with `postgresql` drivers to deploy and run the application on OpenShift

---
### Building a EAP8 container image with applications and IBM MQ resource adapter

1. Clone this repository
2. Build the `Containerfile` using `podman build -t quay.io/<org>/eap8-docker-build .`
3. Update the `settings.xml` and `Containerfile` to change the maven repository to point to a custom repository
