#!/bin/bash
set -e

echo "============================================"
echo "OpenClaw Platform - Local Development Setup"
echo "============================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

# Check for kind
if ! command -v kind &> /dev/null; then
    print_error "kind is not installed. Please install it first:"
    echo "  macOS: brew install kind"
    echo "  Linux: https://kind.sigs.k8s.io/docs/user/quick-start#installation"
    exit 1
fi
print_status "✓ kind is installed"

# Check for kubectl
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first:"
    echo "  https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
print_status "✓ kubectl is installed"

# Check for helm
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed. Please install it first:"
    echo "  https://helm.sh/docs/intro/install/"
    exit 1
fi
print_status "✓ helm is installed"

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Check if kind cluster already exists
if kind get clusters | grep -q "openclaw-platform"; then
    print_warning "kind cluster 'openclaw-platform' already exists"
    read -p "Do you want to delete and recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deleting existing cluster..."
        kind delete cluster --name openclaw-platform
    else
        print_status "Using existing cluster..."
    fi
fi

# Create kind cluster if it doesn't exist
if ! kind get clusters | grep -q "openclaw-platform"; then
    print_status "Creating kind cluster..."
    kind create cluster --config infrastructure/kind/config.yaml
fi

# Verify cluster is running
print_status "Verifying cluster..."
kubectl cluster-info --context kind-openclaw-platform

# Deploy base infrastructure
print_status "Deploying base infrastructure..."
kubectl apply -k infrastructure/kubernetes/kustomize/overlays/local

# Wait for PostgreSQL
print_status "Waiting for PostgreSQL to be ready..."
if ! kubectl wait --for=condition=ready pod -l app=postgres -n platform --timeout=120s; then
    print_error "PostgreSQL failed to start within 120 seconds"
    print_status "You can check the status with: kubectl get pods -n platform"
    exit 1
fi

print_status "✓ PostgreSQL is ready"

# Setup environment variables
print_status ""
print_status "============================================"
print_status "Setup Complete!"
print_status "============================================"
print_status ""
print_status "Next steps:"
print_status ""
print_status "1. Port-forward PostgreSQL (Terminal 1):"
print_status "   kubectl port-forward svc/postgres 5432:5432 -n platform"
print_status ""
print_status "2. Start Phoenix (Terminal 2):"
print_status "   cd apps/platform"
print_status "   mix deps.get"
print_status "   mix ecto.setup"
print_status "   mix phx.server"
print_status ""
print_status "3. Access the application:"
print_status "   http://localhost:4000"
print_status ""
print_status "Test Kubernetes connection:"
print_status "   iex -S mix"
print_status "   ScalingDoodle.Kubernetes.Connection.kubectl(\"local\", [\"get\", \"nodes\"])"
print_status ""
