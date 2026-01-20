# Local CA Toolkit

This project provides simple Bash scripts to create a local Certificate Authority (CA) and issue HTTPS certificates for development. It uses OpenSSL and is intended for local/testing environments.

## What it does

- Initializes a local CA with a master password.
- Issues host certificates (including wildcard) without password protection on the host key.
- Lets you rotate the CA master password.

## Dependencies

- Bash
- OpenSSL

### Install on macOS

```bash
brew install openssl
```

Notes:
- Ensure `openssl` is available in your PATH (Homebrew installs it as `openssl`).

### Install on Ubuntu/Debian

```bash
sudo apt update
sudo apt install -y openssl
```

### Install on Fedora/RHEL

```bash
sudo dnf install -y openssl
```

### Install on Arch Linux

```bash
sudo pacman -S openssl
```

### Windows

Recommended: use WSL with a Linux distribution and install OpenSSL there.

## Usage

### 1) Initialize the CA

```bash
./init_ca.sh
```

This creates the CA key and certificate in `ca/`.

### 2) Issue a certificate

```bash
./issue_cert.sh example.local 90
./issue_cert.sh example.local 90d
./issue_cert.sh example.local 6m
./issue_cert.sh '*.example.local' 1y
```

Outputs are written to `issued/<hostname>/` (or `issued/[star].example.local/` for wildcard), including:
- `*.key.pem` (host key, no password)
- `*.cert.pem`
- `*.fullchain.pem` (host cert + CA cert)

### 3) Issue a client certificate or CSR

Use this when you need a client certificate (for mTLS) or just a CSR to send to another CA.

```bash
./issue_cert_client.sh client1.local 90
./issue_cert_client.sh client1.local 90d
./issue_cert_client.sh client1.local 6m
./issue_cert_client.sh client1.local 1y
```

Outputs are written to `issued/<hostname>/`, including:
- `*.key.pem`
- `*.csr.pem`
- `*.cert.pem`
- `*.fullchain.pem` (client cert + CA cert)

If you only need a CSR and key (no signing), use:

```bash
./issue_cert_client.sh --csr-only client1.local
```

### 4) Change CA master password

```bash
./change_ca_password.sh
```

## Trusting the CA certificate

To avoid browser warnings, import `ca/certs/ca.cert.pem` into your system trust store. Steps vary by OS and browser.

### macOS (system-wide)

1) Open **Keychain Access**.
2) Drag `ca/certs/ca.cert.pem` into the **System** keychain.
3) Double click the certificate, expand **Trust**, set **When using this certificate** to **Always Trust**.

### Windows (system-wide)

1) Run `certmgr.msc`.
2) In **Trusted Root Certification Authorities**, right-click **Certificates** -> **All Tasks** -> **Import**.
3) Select `ca/certs/ca.cert.pem` and complete the wizard.

### Linux (system-wide)

#### Ubuntu/Debian

```bash
sudo cp ca/certs/ca.cert.pem /usr/local/share/ca-certificates/local-dev-ca.crt
sudo update-ca-certificates
```

#### Fedora/RHEL

```bash
sudo cp ca/certs/ca.cert.pem /etc/pki/ca-trust/source/anchors/local-dev-ca.crt
sudo update-ca-trust
```

#### Arch Linux

```bash
sudo cp ca/certs/ca.cert.pem /etc/ca-certificates/trust-source/anchors/local-dev-ca.crt
sudo update-ca-trust
```

### Firefox (per-browser)

Firefox uses its own certificate store by default.

1) Open **Settings** -> **Privacy & Security** -> **Certificates** -> **View Certificates**.
2) Under **Authorities**, click **Import** and select `ca/certs/ca.cert.pem`.
3) Check **Trust this CA to identify websites** and confirm.

## Notes

- For development/testing domains, prefer `.test` (see RFC 6761: https://www.rfc-editor.org/rfc/rfc6761).
- Wildcard certificates should be of the form `*.domain.tld` and are valid for all second-level subdomains.
- This project is for local development/testing only. Do not use for public production services.
