# yubipiv-ca

基于 Alpine 的镜像，包含 `yubico-piv-tool` 和 OpenSSL 的 libp11 PKCS#11
provider，用 YubiKey PIV 槽位充当小型 CA。没有封装脚本，入口就是 `/bin/sh`。

[English](README.md)

```sh
podman build -t yubipiv-ca .
# 或：podman pull ghcr.io/OWNER/yubipiv-ca:latest

podman run --rm -it \
  -v /run/pcscd:/run/pcscd:ro \
  -v "$PWD:/work" \
  yubipiv-ca
```

## 创建 CA

```sh
PIN=123456
yubico-piv-tool -a generate -s 9a -A RSA2048 -o public.pem
yubico-piv-tool -a verify-pin -P "$PIN" -a selfsign-certificate -s 9a \
  -S '/CN=My PIV CA/' --valid-days 3650 -i public.pem -o ca.pem
yubico-piv-tool -a import-certificate -s 9a -i ca.pem
```

这会替换槽位里原有的密钥和证书。如果管理密钥不是默认值，给 `generate` 和
`import-certificate` 加 `--key <hex>`。槽位：`9a`（默认）、`9c`、`9d`、`9e`、
`82`–`95`；不要把 `9e` 用作 CA。

## 签发 CSR

`leaf.cnf`：

```ini
[ leaf ]
basicConstraints = critical, CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
keyUsage = critical, digitalSignature
# extendedKeyUsage = serverAuth
```

```sh
export PKCS11_MODULE_PATH=/usr/lib/libykcs11.so.2
export PKCS11_PIN="$PIN"
export PKCS11_FORCE_LOGIN=1
export PKCS11_DEBUG_LEVEL=0

openssl x509 -req \
  -provider-path /usr/lib/ossl-modules -provider default -provider pkcs11prov \
  -in request.csr -CA ca.pem \
  -CAkey 'pkcs11:object=Private%20key%20for%20PIV%20Authentication;type=private' \
  -set_serial "0x$(openssl rand -hex 16)" -days 365 -sha256 \
  -extfile leaf.cnf -extensions leaf \
  -copy_extensions copy -ext subjectAltName \
  -out certificate.pem

openssl verify -check_ss_sig -CAfile ca.pem -purpose any certificate.pem
```

PKCS#11 密钥标签：`9a` PIV Authentication、`9c` Digital Signature、`9d` Key
Management、`9e` Card Authentication、`82`–`95` Retired Key 1–20。
