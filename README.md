# CA Certificate Bundle

Simple tool to extract and manage CA certificates from proxy/firewall environments.

## Quick Start

```bash
# Create CA certificate bundle
make

# Test the generated bundle
make test

# Verify with multiple domains
make verify

# Clean up generated files
make clean
```

## Usage

- `make` - Extract CA certificates from github.com (default)
- `make DOMAIN=google.com` - Extract from any domain
- `make test` - Test the CA bundle works
- `make verify` - Test with multiple domains
- `make info` - Show certificate information
- `make clean` - Remove all generated files
- `make help` - Show detailed help

## Output

Creates `ca-bundle.pem` containing the root and intermediate CA certificates needed for HTTPS connections in corporate environments.

## Personal Setup

I usually copy the generated `ca-bundle.pem` to my home directory for system-wide use:

```bash
# After running make
cp ca-bundle.pem ~/ca-bundle.pem
```

## Usage

```bash
export CERT_FILE="$HOME/ca-bundle.pem"
export SSL_CERT_FILE="$CERT_FILE"
export CURL_CA_BUNDLE="$CERT_FILE"
export REQUESTS_CA_BUNDLE="$CERT_FILE"
duckdb -ui
```

## Requirements

- `openssl` command-line tool
- Network access to target domain
- Certificate interception
