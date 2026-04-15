from kubernetes import config


def load_kube_config():
    try:
        config.load_incluster_config()
        print("Loaded in-cluster Kubernetes config")
    except Exception:
        config.load_kube_config()
        print("Loaded local Kubernetes config")
