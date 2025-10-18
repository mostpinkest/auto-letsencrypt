# mostpinkest/auto-letsencrypt

A Docker image to automatically request and renew SSL/TLS certificates from [Let's Encrypt](https://letsencrypt.org/) using [certbot](https://certbot.eff.org/about/) and the [Webroot](https://certbot.eff.org/docs/using.html#webroot) or [Cloudflare DNS](https://certbot-dns-cloudflare.readthedocs.io/en/stable/) method for domain validation. This image is also capable of sending a `HUP` signal to Docker container(s) running a web server in order to use the freshly minted certificates.

Based on the [quay.io/letsencrypt/letsencrypt](https://quay.io/repository/letsencrypt/letsencrypt) base image and inspired by [kvaps/letsencrypt-webroot](https://github.com/kvaps/docker-letsencrypt-webroot). Modified for [Cloudflare DNS](https://certbot-dns-cloudflare.readthedocs.io/en/stable/) support by [mostpinkest](https://github.com/mostpinkest)

For ease of auditability, this version is simplified with configuration removed or generalized.

**Contents:**

- [Usage](#usage)
  - [Webroot](#webroot)
  - [Cloudflare DNS](#cloudflare-dns)
- [Optional features](#optional-features)
  - [Reload server configuration](#reload-server-configuration)
  - [Copy certificates to another directory](#copy-certificates-to-another-directory)
  - [Customize webroot path](#customize-webroot-path)
  - [Change the check frequency](#change-the-check-frequency)
  - [Change DNS propagation delay](#change-dns-propagation-delay)
- [Configuration](#configuration)


## Usage
### Webroot
Verify domain ownership by hosting a file. The webroot method works on any server hosting the website on port 80 or 443.

The webroot method assumes a web server is set up to serve ACME challenge files. For example, using Nginx:

```nginx
location '/.well-known/acme-challenge' {
  root /var/www;
}
```

Your server container should be configured to be able use certificates retrieved by `certbot`. The certificates can be found at `/etc/letsencrypt/live/example.com` or be copied to a directory of your choice (see below). For example, using Nginx:

```nginx
ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
```

Run this image:

```sh
docker run -d
  -e 'DOMAINS=example.com www.example.com' \
  -e EMAIL=you@example.com \
  -e SERVER_CONTAINER=nginx \
  -e WEBROOT_PATH=/var/www \
  -e CERTS_PATH=/etc/nginx/certs \
  -e CHECK_FREQ=7 \
  -v /tmp/letsencrypt:/var/www \
  -v /etc/nginx/certs:/etc/nginx/certs \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/letsencrypt:/etc/letsencrypt \
  -v /var/log/letsencrypt/:/var/log/letsencrypt \
  -v /var/lib/letsencrypt:/var/lib/letsencrypt \
  mostpinkest/auto-letsencrypt
```

Docker compose:

```yaml
version: '2'

services:
  nginx:
    image: nginx
    volumes:
      - certs:/etc/nginx/certs
      - /tmp/letsencrypt/www:/tmp/letsencrypt/www
    ports:
      - "80:80"
      - "443:443"
    restart: unless-stopped

  letsencrypt:
    image: mostpinkest/auto-letsencrypt
    volumes:
      - /tmp/letsencrypt/www:/tmp/letsencrypt/www
      - certs:/etc/nginx/certs
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/letsencrypt:/etc/letsencrypt
      - /var/log/letsencrypt/:/var/log/letsencrypt
      - /var/lib/letsencrypt:/var/lib/letsencrypt
    environment:
      - DOMAINS=example.com www.example.com
      - EMAIL=you@example.com
      - SERVER_CONTAINER=nginx
      - WEBROOT_PATH=/tmp/letsencrypt/www
      - CERTS_PATH=/etc/nginx/certs
      - CHECK_FREQ=7
    restart: unless-stopped
    depends_on:
      - nginx

  volumes:
    certs:
```

The container will attempt to request and renew SSL/TLS certificates for the specified domains and automatically repeat the renew process periodically (default is every 30 days).

### Cloudflare DNS
Verify domain ownership through a DNS record. The Cloudflare DNS requires the [domain's primary DNS provider to be Cloudflare](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/). By verifying through DNS, wildcard (`*.example.com`) certificates can also be created.

For `certbot` to create the required DNS reocrd, it needs to authenticate with an API Token (recomended) or a Global API Key (not recommended). Follow [these instructions](https://certbot-dns-cloudflare.readthedocs.io/en/stable/#credentials) to create the credential and save it to a `.ini` file. This file must be bound to this image at the path specified by `CLOUDFLARE_CREDENTIALS`.

Your server container should be configured to be able use certificates retrieved by `certbot`. The certificates can be found at `/etc/letsencrypt/live/example.com` or be copied to a directory of your choice (see below). For example, using Nginx:

```nginx
ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
```

Run this image:

```sh
docker run -d
  -e 'DOMAINS=*.example.com' \
  -e EMAIL=you@example.com \
  -e CLOUDFLARE_CREDENTIAL=/cloudflare-credential.ini \
  -e CLOUDFLARE_PROPAGATION_SECONDS=10 \
  -e SERVER_CONTAINER=nginx \
  -e CERTS_PATH=/etc/nginx/certs \
  -e CHECK_FREQ=7 \
  -v /etc/nginx/certs:/etc/nginx/certs \
  -v ./cloudflare-credential.ini:/cloudflare-credential.ini \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/letsencrypt:/etc/letsencrypt \
  -v /var/log/letsencrypt/:/var/log/letsencrypt \
  -v /var/lib/letsencrypt:/var/lib/letsencrypt \
  mostpinkest/auto-letsencrypt
```

Docker compose:

```yaml
version: '2'

services:
  nginx:
    image: nginx
    volumes:
      - certs:/etc/nginx/certs
    ports:
      - "443:443"
    restart: unless-stopped

  letsencrypt:
    image: mostpinkest/auto-letsencrypt
    volumes:
      - certs:/etc/nginx/certs
      - ./cloudflare-credential.ini:/cloudflare-credential.ini
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/letsencrypt:/etc/letsencrypt
      - /var/log/letsencrypt/:/var/log/letsencrypt
      - /var/lib/letsencrypt:/var/lib/letsencrypt
    environment:
      - DOMAINS=*.example.com
      - EMAIL=you@example.com
      - CLOUDFLARE_CREDENTIAL=/cloudflare-credential.ini
      - CLOUDFLARE_PROPAGATION_SECONDS=10
      - SERVER_CONTAINER=nginx
      - CERTS_PATH=/etc/nginx/certs
      - CHECK_FREQ=7
    restart: unless-stopped
    depends_on:
      - nginx

  volumes:
    certs:
```

The container will attempt to request and renew SSL/TLS certificates for the specified domains and automatically repeat the renew process periodically (default is every 30 days).

## Optional features

### Reload server configuration
To automatically reload the server configuration to use the new certificates, provide the container name(s) to the environment variable `SERVER_CONTAINER` and pass through the Docker socket to this container: `-v /var/run/docker.sock:/var/run/docker.sock`. The image will send a `HUP` signal to the specified container(s). multiple containers can be specified by seperating them by spaces. Container labels can also be used with `SERVER_CONTAINER_LABEL`.

### Copy certificates to another directory
Provide a directory path to the `CERTS_PATH` environment variable if you wish to copy the certificates to another directory. You may wish to do this in order to avoid exposing the entire `/etc/letsencrypt/` directory to your web server container.

### Customize webroot path
To configure the webroot path use the `WEBROOT_PATH` environment variable. The default is `/var/www`.

### Change the check frequency
Provide a number to the `CHECK_FREQ` environment variable to adjust how often it attempts to renew a certificate. The default is 30 days. Please note `certbot` is configured to keep matching certificates until one is due for renewal, avoiding unnecessary renewals.

### Change DNS propagation delay
Provide a number to the `CLOUDFLARE_PROPAGATION_SECONDS` environment variable to adjust the number of seconds to wait before verifying the DNS record. The default is 10 seconds.

## Configuration

| Environment Varibale | Description |
| --- | --- |
| `DOMAINS` | Domains for your certificate. e.g. `example.com www.example.com *.example.com`. |
| `EMAIL` | Email for urgent notices and lost key recovery. e.g. `you@example.com`. |
| `WEBROOT_PATH` | Defaults to `/var/www`. Required for the webroot method. Path to the letsencrypt directory in the web server for checks. |
| `CLOUDFLARE_CREDENTIAL` | Required for Cloudflare DNS. Cloudflare credentials .ini file. [Learn more](https://certbot-dns-cloudflare.readthedocs.io/en/stable/#credentials) |
| `CLOUDFLARE_PROPAGATION_SECONDS` | Defaults to `10`. The number of seconds to wait for DNS to propagate before verifying the DNS record. |
| `CERTS_PATH` | Optional. Copy the new certificates to the specified path. e.g. `/etc/nginx/certs`. |
| `SERVER_CONTAINER` | Optional. The Docker container name(s) of the server(s) you wish to send a `HUP` signal to in order to reload the configuration and use the new certificates. |
| `SERVER_CONTAINER_LABEL` | Optional. The Docker container label of the server you wish to send a `HUP` signal to in order to reload its configuration and use the new certificates. This environment variable will be helpfull in case of deploying with docker swarm since docker swarm will create container name itself. |
| `CHECK_FREQ` | Defaults to `30`. How often (in days) to perform checks. |
