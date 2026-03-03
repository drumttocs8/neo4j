#!/bin/bash
# init-n10s.sh — Starts Neo4j, waits for it, then bootstraps n10s.
# On subsequent starts the constraint + graphconfig already exist so
# the Cypher statements are idempotent no-ops.

set -euo pipefail

##############################################################################
# 1. Start Neo4j in the background via the official Docker entrypoint
##############################################################################
/startup/docker-entrypoint.sh neo4j &
NEO4J_PID=$!

##############################################################################
# 2. Wait until the Bolt port is accepting connections
##############################################################################
echo "[init-n10s] Waiting for Neo4j to become ready..."
MAX_WAIT=120          # seconds
ELAPSED=0
INTERVAL=3

# Resolve auth for cypher-shell
NEO4J_USER="neo4j"
NEO4J_PASS="${NEO4J_AUTH#*/}"   # strip "neo4j/" prefix

until cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASS" "RETURN 1;" >/dev/null 2>&1; do
    sleep "$INTERVAL"
    ELAPSED=$((ELAPSED + INTERVAL))
    if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
        echo "[init-n10s] ⚠  Neo4j did not become ready within ${MAX_WAIT}s — skipping bootstrap"
        wait "$NEO4J_PID"
        exit $?
    fi
done

echo "[init-n10s] Neo4j is ready (${ELAPSED}s elapsed). Bootstrapping n10s..."

##############################################################################
# 3. Create the unique URI constraint required by n10s (idempotent)
##############################################################################
cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASS" \
  "CREATE CONSTRAINT n10s_unique_uri IF NOT EXISTS FOR (r:Resource) REQUIRE r.uri IS UNIQUE;" \
  2>/dev/null || echo "[init-n10s] Constraint already exists or unsupported — continuing"

##############################################################################
# 4. Initialise the n10s graph config (idempotent)
#    - handleVocabUris: "SHORTEN" maps long IRIs to short prefixes
#    - handleMultival: "ARRAY"  stores multi-valued properties as lists
#    - keepLangTag / keepCustomDataTypes keep RDF fidelity
##############################################################################
cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASS" <<'CYPHER'
CALL n10s.graphconfig.init({
  handleVocabUris:      "SHORTEN",
  handleMultival:        "OVERWRITE",
  keepLangTag:           true,
  keepCustomDataTypes:   true,
  typesToLabels:         true
});
CYPHER
echo "[init-n10s] ✓  n10s graph config initialised"

##############################################################################
# 5. Add CIM namespace prefixes so Cypher is readable
##############################################################################
cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASS" <<'CYPHER'
// IEC CIM 100 (most common)
CALL n10s.nsprefixes.add("cim",  "http://iec.ch/TC57/CIM100#");
// IEC CIM 17
CALL n10s.nsprefixes.add("cim17","http://iec.ch/TC57/CIM100-17#");
// RDF / RDFS / OWL basics
CALL n10s.nsprefixes.add("rdf",  "http://www.w3.org/1999/02/22-rdf-syntax-ns#");
CALL n10s.nsprefixes.add("rdfs", "http://www.w3.org/2000/01/rdf-schema#");
CALL n10s.nsprefixes.add("owl",  "http://www.w3.org/2002/07/owl#");
CALL n10s.nsprefixes.add("xsd",  "http://www.w3.org/2001/XMLSchema#");
CYPHER
echo "[init-n10s] ✓  CIM namespace prefixes registered"

echo "[init-n10s] ✓  Bootstrap complete — Neo4j is running with n10s"

##############################################################################
# 6. Keep the container alive by waiting on the Neo4j process
##############################################################################
wait "$NEO4J_PID"
