# Neo4j with neosemantics (n10s) + APOC plugins for CIM RDF import
# Ref: https://neo4j.com/docs/operations-manual/current/docker/plugins/
#      https://neo4j.com/labs/neosemantics/installation/
#
# Strategy: Let NEO4J_PLUGINS handle plugin download at startup.
# No pre-seeding, no entrypoint override — vanilla Neo4j image + env vars.

FROM neo4j:5-community

# ── Plugins (auto-downloaded on first start) ────────────────────────
ENV NEO4J_PLUGINS='["n10s", "apoc"]'

# ── Neo4j configuration ─────────────────────────────────────────────
# Enable the n10s RDF HTTP endpoint
ENV NEO4J_server_unmanaged__extension__classes=n10s.endpoint=/rdf

# Allow n10s + apoc procedures (unrestricted)
ENV NEO4J_dbms_security_procedures_unrestricted=n10s.*,apoc.*

# ── Networking ──────────────────────────────────────────────────────
# Listen on all interfaces (required for Railway / Docker networking)
ENV NEO4J_server_default__listen__address=0.0.0.0

# Bolt & HTTP on standard ports
ENV NEO4J_server_http_listen__address=:7474
ENV NEO4J_server_bolt_listen__address=:7687

# ── Memory ──────────────────────────────────────────────────────────
# Conservative defaults for Railway; override via Railway env vars
ENV NEO4J_server_memory_heap_initial__size=256m
ENV NEO4J_server_memory_heap_max__size=512m
ENV NEO4J_server_memory_pagecache_size=128m

# ── Auth ────────────────────────────────────────────────────────────
# Default dev credentials — override NEO4J_AUTH in Railway env vars
ENV NEO4J_AUTH=neo4j/verance-ai-dev

# ── Railway port routing ────────────────────────────────────────────
ENV PORT=7474
EXPOSE 7474 7687

# Keep the n10s bootstrap script available for manual use:
#   docker exec <container> /scripts/init-n10s.sh
COPY init-n10s.sh /scripts/init-n10s.sh
RUN sed -i 's/\r$//' /scripts/init-n10s.sh && chmod +x /scripts/init-n10s.sh

# Use the default Neo4j entrypoint + cmd (no override)
# ENTRYPOINT ["tini", "-g", "--", "/startup/docker-entrypoint.sh"]
# CMD ["neo4j"]
