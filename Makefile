# Makefile to recreate ca-bundle.pem from live certificate chain
# This extracts the CA certificates from any HTTPS site that uses the same proxy/firewall

.PHONY: all clean help test verify

# Default target domain (can be overridden)
DOMAIN ?= github.com
PORT ?= 443

# Output files
CA_BUNDLE = ca-bundle.pem
TEMP_CERTS = temp-certs.txt
ROOT_CA = root-ca.pem
INTERMEDIATE_CA = intermediate-ca.pem

all: $(CA_BUNDLE)

help:
	@echo "Makefile to recreate CA bundle from live certificate chain"
	@echo ""
	@echo "Usage:"
	@echo "  make                 # Extract CA certs from github.com (default)"
	@echo "  make DOMAIN=google.com # Extract CA certs from google.com"
	@echo "  make clean           # Remove generated files"
	@echo "  make test            # Test the generated CA bundle"
	@echo "  make verify          # Verify CA bundle works with multiple domains"
	@echo ""
	@echo "Requirements:"
	@echo "  - openssl command-line tool"
	@echo "  - Network access to target domain"

$(CA_BUNDLE): $(TEMP_CERTS)
	@echo "Extracting CA certificates from certificate chain..."
	
	# Extract individual certificates from the chain
	@awk 'BEGIN{cert=""} \
	/-----BEGIN CERTIFICATE-----/{cert=$$0 ORS; flag=1; next} \
	flag{cert=cert $$0 ORS} \
	/-----END CERTIFICATE-----/{print cert > "cert" ++i ".pem"; cert=""; flag=0}' $(TEMP_CERTS)
	
	# Identify and rename certificates based on their subject/issuer
	@for cert in cert*.pem; do \
		subject=$$(openssl x509 -in $$cert -noout -subject 2>/dev/null); \
		issuer=$$(openssl x509 -in $$cert -noout -issuer 2>/dev/null); \
		if echo "$$subject" | grep -q "CN=SB1A-ROOT-CA" && echo "$$issuer" | grep -q "CN=SB1A-ROOT-CA"; then \
			mv $$cert $(ROOT_CA); \
			echo "Found root CA certificate: $$subject"; \
		elif echo "$$issuer" | grep -q "CN=SB1A-ROOT-CA"; then \
			mv $$cert $(INTERMEDIATE_CA); \
			echo "Found intermediate CA certificate: $$subject"; \
		else \
			echo "Removing end-entity certificate: $$subject"; \
			rm -f $$cert; \
		fi; \
	done
	
	# Create CA bundle (root + intermediate)
	@if [ -f $(ROOT_CA) ] && [ -f $(INTERMEDIATE_CA) ]; then \
		cat $(ROOT_CA) $(INTERMEDIATE_CA) > $(CA_BUNDLE); \
		echo "Created $(CA_BUNDLE) with root and intermediate CA certificates"; \
		echo "CA bundle contains $$(grep -c 'BEGIN CERTIFICATE' $(CA_BUNDLE)) certificate(s)"; \
	else \
		echo "Error: Could not find both root and intermediate CA certificates"; \
		exit 1; \
	fi
	
	# Clean up temporary files
	@rm -f $(ROOT_CA) $(INTERMEDIATE_CA) $(TEMP_CERTS)

$(TEMP_CERTS):
	@echo "Fetching certificate chain from $(DOMAIN):$(PORT)..."
	@openssl s_client -connect $(DOMAIN):$(PORT) -showcerts </dev/null 2>/dev/null > $(TEMP_CERTS)
	@if [ ! -s $(TEMP_CERTS) ]; then \
		echo "Error: Failed to fetch certificates from $(DOMAIN):$(PORT)"; \
		rm -f $(TEMP_CERTS); \
		exit 1; \
	fi
	@cert_count=$$(grep -c 'BEGIN CERTIFICATE' $(TEMP_CERTS)); \
	echo "Retrieved certificate chain with $$cert_count certificate(s)"

test: $(CA_BUNDLE)
	@echo "Testing CA bundle with $(DOMAIN)..."
	@if openssl s_client -connect $(DOMAIN):$(PORT) -CAfile $(CA_BUNDLE) -verify_return_error -brief </dev/null 2>&1 | grep -q "Verification: OK"; then \
		echo "✓ CA bundle verification successful for $(DOMAIN)"; \
	else \
		echo "✗ CA bundle verification failed for $(DOMAIN)"; \
		exit 1; \
	fi

verify: $(CA_BUNDLE)
	@echo "Verifying CA bundle with multiple domains..."
	@domains="github.com google.com stackoverflow.com"; \
	success=0; total=0; \
	for domain in $$domains; do \
		total=$$((total + 1)); \
		printf "Testing $$domain... "; \
		if openssl s_client -connect $$domain:443 -CAfile $(CA_BUNDLE) -verify_return_error -brief </dev/null 2>&1 | grep -q "Verification: OK"; then \
			echo "✓"; \
			success=$$((success + 1)); \
		else \
			echo "✗"; \
		fi; \
	done; \
	echo "Verification results: $$success/$$total domains successful"; \
	if [ $$success -eq $$total ]; then \
		echo "🎉 All verifications passed!"; \
	else \
		echo "⚠️  Some verifications failed"; \
		exit 1; \
	fi

clean:
	@echo "Cleaning up generated files..."
	@rm -f $(CA_BUNDLE) $(TEMP_CERTS) $(ROOT_CA) $(INTERMEDIATE_CA) cert*.pem
	@echo "Cleanup complete"

# Display information about the current CA bundle
info:
	@if [ -f $(CA_BUNDLE) ]; then \
		echo "CA Bundle Information:"; \
		echo "====================="; \
		echo "File: $(CA_BUNDLE)"; \
		echo "Size: $$(wc -c < $(CA_BUNDLE)) bytes"; \
		echo "Certificates: $$(grep -c 'BEGIN CERTIFICATE' $(CA_BUNDLE))"; \
		echo ""; \
		echo "Certificate Details:"; \
		echo "-------------------"; \
	else \
		echo "CA bundle not found. Run 'make' to create it."; \
	fi
