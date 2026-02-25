# Well-lit Path: Encoder-Decode-Prefill Disaggregation

## Overview

This guide deploys an encoder-decode-prefill (E-DP) disaggregation configuration for vLLM deployments. This architecture separates the encoding workload from the decode-prefill workload using two distinct pod types:

1. **Encoder Pod**: Handles multimodal encoding (e.g., image/video processing) with the `--mm-encoder-only` flag
2. **Decode-Prefill Pod**: Handles text generation (prefill and decode phases) consuming encoded data

The pods communicate via a shared storage mechanism using the EC (Encoder-Consumer) transfer configuration, enabling efficient processing of multimodal inputs.

## Hardware Requirements

This example uses GPUs for both encoder and decode-prefill pods:

- **NVIDIA GPUs**: Any NVIDIA GPU (support determined by the inferencing image used)
- **Intel XPU/GPUs**: Intel Data Center GPU Max 1550 or compatible Intel XPU device
- **TPUs**: Google Cloud TPUs (when using GKE TPU configuration)

**Default Configuration**: 
- 1 encoder pod replica
- 1 decode-prefill pod replica

**Using fewer/more accelerators**: Modify the `replicas` field in [ms-e-dp-disaggregation/values.yaml](./ms-e-dp-disaggregation/values.yaml) for the `encode` and `prefill` sections.

## Prerequisites

- Have the [proper client tools installed on your local system](../prereq/client-setup/README.md) to use this guide.
- Ensure your cluster infrastructure is sufficient to [deploy high scale inference](../prereq/infrastructure)
- Have the [Monitoring stack](../../docs/monitoring/README.md) installed on your system.
- Create a namespace for installation.

  ```bash
  export NAMESPACE=llm-d-e-dp-disaggregation # or any other namespace (shorter names recommended)
  kubectl create namespace ${NAMESPACE}
  ```

- [Create the `llm-d-hf-token` secret in your target namespace with the key `HF_TOKEN` matching a valid HuggingFace token](../prereq/client-setup/README.md#huggingface-token) to pull models.
- [Choose an llm-d version](../prereq/client-setup/README.md#llm-d-version)
- Configure and deploy your [Gateway control plane](../prereq/gateway-provider/README.md)

## EC Cache Setup

The EC (Encoder-Consumer) cache is automatically created during helmfile deployment via a presync hook. The cache uses:
- **PersistentVolume**: `ec-cache-pv` with 5Gi storage
- **PersistentVolumeClaim**: `ec-cache-pvc` in your namespace
- **Storage**: hostPath at `/tmp/vllm-ec-cache` (for development/testing)

**Note**: For production deployments, modify `ec-cache.yaml` to use a proper shared storage solution (NFS, CephFS, etc.) instead of hostPath before deploying.

## Installation

Use the helmfile to compose and install the stack. The Namespace in which the stack will be deployed will be derived from the `${NAMESPACE}` environment variable. If you have not set this, it will default to `llm-d-e-dp-disaggregation` in this example.

**_IMPORTANT:_** When using long namespace names (like `llm-d-e-dp-disaggregation`), the generated pod hostnames may become too long and cause issues due to Linux hostname length limitations (typically 64 characters maximum). It's recommended to use shorter namespace names (like `llm-d-edp`) and set `RELEASE_NAME_POSTFIX` to generate shorter hostnames and avoid potential networking or vLLM startup problems.

### Deploy

```bash
cd guides/e-dp-disaggregation
```

#### Dry Run (Recommended First)

Before actually deploying, you can perform a dry run to see what resources will be created:

```bash
# Dry run with helmfile (shows what would be applied)
helmfile --debug diff -n ${NAMESPACE}

# Or use helm template to see the rendered manifests (all releases)
helmfile template -n ${NAMESPACE}

# For a specific release (e.g., just the modelservice):
helmfile -l name=ms-e-dp-disaggregation template -n ${NAMESPACE}

# To verify the role labels in the rendered manifests:
helmfile -l name=ms-e-dp-disaggregation template -n ${NAMESPACE} | grep -A 2 "llm-d.ai/role"
```

**Note:** The modified chart natively supports `encode` and `prefill-decode` role labels, so you should see these values directly in the rendered templates without any post-deployment patching.

<!-- TABS:START -->
<!-- TAB:GPU deployment  -->

#### GPU deployment

```bash
helmfile apply -n ${NAMESPACE}
```

<!-- TABS:END -->

**_NOTE:_** You can set the `$RELEASE_NAME_POSTFIX` env variable to change the release names. This is how we support concurrent installs. Ex: `RELEASE_NAME_POSTFIX=e-dp-disaggregation-2 helmfile apply -n ${NAMESPACE}`

### Gateway and Hardware Options

#### Gateway Options

**_NOTE:_** This uses Istio as the default gateway provider, see [Gateway Option](#gateway-option) for installing with a specific provider.

To specify your gateway choice you can use the `-e <gateway option>` flag, ex:

```bash
helmfile apply -e kgateway -n ${NAMESPACE}
```

To see what gateway options are supported refer to our [gateway provider prereq doc](../prereq/gateway-provider/README.md#supported-providers). Gateway configurations per provider are tracked in the [gateway-configurations directory](../prereq/gateway-provider/common-configurations/).

You can also customize your gateway, for more information on how to do that see our [gateway customization docs](../../docs/customizing-your-gateway.md).

### Install HTTPRoute When Using Gateway option

Follow provider specific instructions for installing HTTPRoute.

#### Install for "kgateway" or "istio"

```bash
kubectl apply -f httproute.yaml -n ${NAMESPACE}
```

#### Install for "gke"

```bash
kubectl apply -f httproute.gke.yaml -n ${NAMESPACE}
```

## Verify the Installation

- Firstly, you should be able to list all helm releases to view the 3 charts got installed into your chosen namespace:

```bash
helm list -n ${NAMESPACE}
NAME                            NAMESPACE                       REVISION  UPDATED                                 STATUS      CHART                       APP VERSION
gaie-e-dp-disaggregation        llm-d-e-dp-disaggregation       1         2026-02-24 14:00:00.000000 +0200 IST    deployed    inferencepool-v1.3.0        v1.3.0
infra-e-dp-disaggregation       llm-d-e-dp-disaggregation       1         2026-02-24 14:00:00.000000 +0200 IST    deployed    llm-d-infra-v1.3.6          v0.3.0
ms-e-dp-disaggregation          llm-d-e-dp-disaggregation       1         2026-02-24 14:00:00.000000 +0200 IST    deployed    llm-d-modelservice-v0.4.5   v0.4.0
```

- Out of the box with this example you should have the following resources:

```bash
kubectl get all -n ${NAMESPACE}
```

You should see:
- Encoder pods with label `llm-d.ai/role: encode`
- Decode-prefill pods with label `llm-d.ai/role: prefill-decode`
- Gateway and InferencePool resources

To verify the pod labels:

```bash
# Encoder pods (labeled as 'encode')
kubectl get pods -n ${NAMESPACE} -l llm-d.ai/role=encode

# Decode-prefill pods (labeled as 'prefill-decode')
kubectl get pods -n ${NAMESPACE} -l llm-d.ai/role=prefill-decode
```

Or check the deployment labels directly:

```bash
kubectl get deployment -n ${NAMESPACE} -o yaml | grep -A 3 "llm-d.ai/role"
```

## Using the stack

For instructions on getting started making inference requests see [our docs](../../docs/getting-started-inferencing.md)

## Architecture Details

### Encoder Pod (deployed as `encode` in values.yaml)
- Runs vLLM with `--mm-encoder-only` flag
- Processes multimodal inputs (images, videos)
- Produces encoded representations stored in shared EC cache
- Acts as EC producer with `"ec_role": "ec_producer"`
- **Label**: `llm-d.ai/role: encode` (natively supported by chart)

### Decode-Prefill Pod (deployed as `prefillDecode` in values.yaml)
- Runs vLLM for text generation
- Includes routing sidecar for request distribution (configured via `routing.proxy`)
- Consumes encoded data from shared EC cache
- Acts as EC consumer with `"ec_role": "ec_consumer"`
- Handles both prefill and decode phases
- **Label**: `llm-d.ai/role: prefill-decode` (natively supported by chart)

**Native E-DP Support**: This guide uses a modified version of the llm-d-modelservice chart from https://github.com/revit13/llm-d-modelservice/tree/e_pd that natively supports encoder-decode-prefill disaggregation with dedicated `encode` and `prefillDecode` sections in values.yaml.

### Communication Flow
1. Request arrives at the gateway
2. Encoder pod processes multimodal input
3. Encoded data written to shared EC cache
4. Decode-prefill pod reads encoded data from cache
5. Text generation proceeds using encoded representations

## Cleanup

To remove the deployment:

```bash
# From guides/e-dp-disaggregation
helmfile destroy -n ${NAMESPACE}

# Or uninstall manually
helm uninstall infra-e-dp-disaggregation -n ${NAMESPACE} --ignore-not-found
helm uninstall gaie-e-dp-disaggregation -n ${NAMESPACE}
helm uninstall ms-e-dp-disaggregation -n ${NAMESPACE}
```

**_NOTE:_** If you set the `$RELEASE_NAME_POSTFIX` environment variable, your release names will be different from the command above: `infra-$RELEASE_NAME_POSTFIX`, `gaie-$RELEASE_NAME_POSTFIX` and `ms-$RELEASE_NAME_POSTFIX`.

### Cleanup HTTPRoute when using Gateway option

Follow provider specific instructions for deleting HTTPRoute.

#### Cleanup for "kgateway" or "istio"

```bash
kubectl delete -f httproute.yaml -n ${NAMESPACE}
```

#### Cleanup for "gke"

```bash
kubectl delete -f httproute.gke.yaml -n ${NAMESPACE}
```

### Cleanup EC Cache Resources

The EC cache resources are not automatically deleted by helmfile. To clean them up manually:

```bash
kubectl delete pvc ec-cache-pvc -n ${NAMESPACE}
kubectl delete pv ec-cache-pv
```

Alternatively, you can use the ec-cache.yaml file:

```bash
kubectl delete -f ec-cache.yaml -n ${NAMESPACE}
```

## Customization

For information on customizing a guide and tips to build your own, see [our docs](../../docs/customizing-a-guide.md)

### Modified Chart for E-DP Disaggregation

This guide uses a modified version of the llm-d-modelservice chart that natively supports encoder-decode-prefill disaggregation with proper role labels:

**Chart Source**: https://github.com/revit13/llm-d-modelservice/tree/e_pd

**Key Features**:
- Uses `encode` section for encoder-only deployments with `--mm-encoder-only` flag
- Uses `prefillDecode` section for decode-prefill deployments
- Native support for `llm-d.ai/role: encode` label on encoder pods
- Native support for `llm-d.ai/role: prefill-decode` label on decode-prefill pods
- Routing sidecar configured via `routing.proxy` section (not initContainers)
- Eliminates need for post-deployment label patching

**Using the Modified Chart**:

The helmfile automatically references the modified chart from the `e_pd` branch:
```yaml
chart: git::https://github.com/revit13/llm-d-modelservice.git@charts/llm-d-modelservice?ref=e_pd
```

**For Local Development**:
```bash
# Clone the modified chart
git clone -b e_pd https://github.com/revit13/llm-d-modelservice.git
cd llm-d-modelservice

# Update helmfile to use local path
# Change: chart: git::https://github.com/revit13/llm-d-modelservice.git@charts/llm-d-modelservice?ref=e_pd
# To: chart: /path/to/llm-d-modelservice/charts/llm-d-modelservice

# Deploy
helmfile apply -n ${NAMESPACE}
```

**Contributing Upstream**: These modifications are intended to be contributed back to the main llm-d-modelservice repository to enable native E-DP disaggregation support for all users.

## References

- [vLLM Encoder-Consumer Transfer Documentation](https://docs.vllm.ai/)
- [Multimodal Processing in vLLM](https://docs.vllm.ai/)