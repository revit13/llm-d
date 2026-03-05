#!/bin/bash

# Check if a namespace was provided as an argument
if [ -z "$1" ]; then
  echo "Error: No namespace provided."
  echo "Usage: $0 <namespace-name>"
  exit 1
fi

# Variables
NAMESPACE=$1
SECRET_NAME=llm-d-hf-token
SOURCE_NS=epd

# 1. Create a unique temporary directory
TEMP_DIR=$(mktemp -d -t llm-d-XXXXXXXXXX)
echo "Created temp directory: $TEMP_DIR"

# 2. Navigate into it
cd "$TEMP_DIR" || exit

# 3. Clone the repository
echo "Cloning llm-d repository..."
git clone https://github.com/revit13/llm-d.git .

# 4. Checkout the e_pd branch
# Note: In git, we 'checkout' branches. 'Namespace' usually refers to k8s.
echo "Checking out e_pd branch..."
git checkout e_pd

echo "--- Workspace Ready ---"
echo "Location: $TEMP_DIR"
cd guides/e-dp-disaggregation
ls -F


echo "Step 1: Creating Namespace (if not exists)..."
kubectl create namespace "$NAMESPACE"

kubectl config set-context --current --namespace="$NAMESPACE" 

oc adm policy add-scc-to-user anyuid -z ms-e-dp-disaggregation-llm-d-modelservice -n "$NAMESPACE"

oc adm policy add-scc-to-user privileged -z ms-e-dp-disaggregation-llm-d-modelservice -n "$NAMESPACE"

echo "Step 2: Creating Kubernetes Secret..."
# Using --from-literal to avoid creating a separate YAML file
echo "Copying secret '$SECRET_NAME' from '$SOURCE_NS' to '$NAMESPACE'..."

# The 'clean' way to copy a secret:
kubectl get secret "$SECRET_NAME" --namespace="$SOURCE_NS" -o yaml | \
  grep -vE 'namespace:|uid:|resourceVersion:|creationTimestamp:|managedFields:' | \
  kubectl apply --namespace="$NAMESPACE" -f -

echo "Step 3: Installing Helm Chart..."
# HTTPRoute will be automatically applied via presync hook (just like ec-cache.yaml)
# Both 'helmfile apply' and 'helmfile sync' will trigger presync hooks
helmfile apply -n "$NAMESPACE"

kubectl apply -f httproute.yaml -n "$NAMESPACE"

echo "Deployment Complete!"
