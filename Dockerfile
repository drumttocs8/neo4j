# Neo4j with neosemantics (n10s) for CIM RDF import
# Ref: https://neo4j.com/docs/operations-manual/current/docker/plugins/
#      https://neo4j.com/labs/neosemantics/installation/

FROM neo4j:5-community

# ── Pre-seed n10s plugin at build time ───────────────────────────────
ARG N10S_VERSION=5.26.0
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    curl -fSL "https://github.com/neo4j-labs/neosemantics/releases/download/${N10S_VERSION}/neosemantics-${N10S_VERSION}.jar" \
         -o /var/lib/neo4j/plugins/neosemantics-${N10S_VERSION}.jar && \
    apt-get purge -y curl && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# ── Neo4j configuration ─────────────────────────────────────────────
ENV NEO4J_server_unmanaged__extension__classes=n10s.endpoint=/rdf
ENV NEO4J_dbms_security_procedures_unrestricted=n10s.*

# ── Bolt TLS (required for browser access over HTTPS → bolt+s://) ──
RUN mkdir -p /var/lib/neo4j/certificates/bolt/trusted \
             /var/lib/neo4j/certificates/bolt/revoked && \
    openssl req -x509 -newkey rsa:2048 \
      -keyout /var/lib/neo4j/certificates/bolt/private.key \
      -out    /var/lib/neo4j/certificates/bolt/public.crt \
      -days 3650 -nodes -subj "/CN=neo4j" && \
    cp /var/lib/neo4j/certificates/bolt/public.crt \
       /var/lib/neo4j/certificates/bolt/trusted/ && \
    chown -R neo4j:neo4j /var/lib/neo4j/certificates

ENV NEO4J_dbms_ssl_policy_bolt_enabled=true
ENV NEO4J_dbms_ssl_policy_bolt_base__directory=/var/lib/neo4j/certificates/bolt
ENV NEO4J_dbms_ssl_policy_bolt_private__key=private.key
ENV NEO4J_dbms_ssl_policy_bolt_public__certificate=public.crt
ENV NEO4J_dbms_ssl_policy_bolt_client__auth=NONE
ENV NEO4J_server_bolt_tls__level=REQUIRED

# ── Networking ──────────────────────────────────────────────────────
ENV NEO4J_server_default__listen__address=0.0.0.0
ENV NEO4J_server_http_listen__address=:7474
ENV NEO4J_server_bolt_listen__address=:7687

# ── Memory (conservative for Railway) ──────────────────────────────
ENV NEO4J_server_memory_heap_initial__size=128m
ENV NEO4J_server_memory_heap_max__size=256m
ENV NEO4J_server_memory_pagecache_size=64m

# ── Auth ────────────────────────────────────────────────────────────
ENV NEO4J_AUTH=neo4j/verance-ai-dev

# ── Railway port routing ────────────────────────────────────────────
ENV PORT=7474
EXPOSE 7474 7687

# n10s bootstrap script (run manually after first deploy)
COPY init-n10s.sh /scripts/init-n10s.sh
RUN sed -i 's/\r$//' /scripts/init-n10s.sh && chmod +x /scripts/init-n10s.sh
