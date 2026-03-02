# Neo4j + Neosemantics (n10s) — Verance AI Graph Analytics

Neo4j property-graph layer for Verance AI. Consumes CIM RDF models from
Blazegraph via the **neosemantics (n10s)** plugin, then serves as the
analytics / traversal engine for SCADA, protection, and network overlays.

## Why Neo4j alongside Blazegraph?

| Concern | Blazegraph (triplestore) | Neo4j (property graph) |
|---------|--------------------------|------------------------|
| **CIM model storage** | ✅ Native RDF / SPARQL | Import via n10s |
| **Traversal performance** | Adequate for small models | ✅ Index-free adjacency |
| **SCADA/protection overlays** | Awkward — no schema | ✅ Labeled property graph |
| **Visualization** | Limited | ✅ Bloom / Browser |
| **Graph algorithms** | ❌ | ✅ GDS library |

Blazegraph remains the **source of truth** for CIM RDF. Neo4j is the
**analytic mirror** — we import, enrich, and query.

---

## Architecture

```
Blazegraph (CIM RDF)
        │
        │  n10s.rdf.import.fetch (SPARQL endpoint)
        ▼
┌───────────────────────┐
│  Neo4j + n10s         │
│  ├ CIM graph (import) │
│  ├ SCADA overlay      │   ◄── Bloom / external tools
│  ├ Protection overlay  │
│  └ Network overlay     │
└───────┬───────────────┘
        │ Bolt 7687 / HTTP 7474
        ▼
    n8n / CIMgraph API / Bloom
```

---

## Quick Start (local Docker)

```bash
docker build -t verance-neo4j .
docker run -d \
  --name verance-neo4j \
  -p 7474:7474 -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/your-password \
  -v neo4j-data:/data \
  verance-neo4j
```

Open http://localhost:7474 → log in with `neo4j / your-password`.

### Verify n10s is installed

```cypher
SHOW PROCEDURES YIELD name WHERE name STARTS WITH 'n10s' RETURN name;
```

Should return ~50+ procedures (e.g., `n10s.rdf.import.fetch`, `n10s.graphconfig.init`, …).

### Verify RDF endpoint

```
GET http://localhost:7474/rdf/ping
```

---

## Railway Deployment

### Required Environment Variables

Set these in the Railway service dashboard:

| Variable | Value | Notes |
|----------|-------|-------|
| `NEO4J_AUTH` | `neo4j/<strong-password>` | **Change from default!** |
| `PORT` | `7474` | Railway routes public traffic here |

### Optional Tuning Variables

| Variable | Default | Notes |
|----------|---------|-------|
| `NEO4J_server_memory_heap_initial__size` | `256m` | Increase for large models |
| `NEO4J_server_memory_heap_max__size` | `512m` | Match to Railway plan RAM |
| `NEO4J_server_memory_pagecache_size` | `128m` | Cache for graph pages |

### Internal URLs (from other Railway services)

```
HTTP:  http://neo4j.railway.internal:7474
Bolt:  bolt://neo4j.railway.internal:7687
RDF:   http://neo4j.railway.internal:7474/rdf/...
```

---

## Importing CIM from Blazegraph

### Option 1: Fetch directly from Blazegraph SPARQL endpoint

```cypher
// Import all triples from Blazegraph namespace "kb"
CALL n10s.rdf.import.fetch(
  "http://blazegraph.railway.internal:8080/bigdata/namespace/kb/sparql",
  "Turtle",
  {
    headerParams: { Accept: "text/turtle" },
    verifyUriSyntax: false
  }
);
```

### Option 2: Import via CONSTRUCT query (selective)

```cypher
// Import only substation/feeder/equipment triples
CALL n10s.rdf.import.fetch(
  "http://blazegraph.railway.internal:8080/bigdata/namespace/kb/sparql?query=" +
  apoc.text.urlencode("
    CONSTRUCT { ?s ?p ?o }
    WHERE {
      ?s a ?type .
      VALUES ?type {
        <http://iec.ch/TC57/CIM100#Substation>
        <http://iec.ch/TC57/CIM100#Feeder>
        <http://iec.ch/TC57/CIM100#Breaker>
        <http://iec.ch/TC57/CIM100#PowerTransformer>
        <http://iec.ch/TC57/CIM100#ACLineSegment>
        <http://iec.ch/TC57/CIM100#Terminal>
        <http://iec.ch/TC57/CIM100#ConnectivityNode>
      }
      ?s ?p ?o .
    }
  "),
  "Turtle",
  { verifyUriSyntax: false }
);
```

### Option 3: Import from RDF/XML file

```cypher
// Upload file to neo4j import/ directory first, then:
CALL n10s.rdf.import.fetch(
  "file:///var/lib/neo4j/import/model.xml",
  "RDF/XML"
);
```

### Check import results

```cypher
// Count imported nodes by label
MATCH (n) RETURN labels(n) AS label, count(*) AS count ORDER BY count DESC;

// Browse CIM classes
MATCH (n:Resource) RETURN DISTINCT labels(n), count(*) ORDER BY count(*) DESC LIMIT 20;

// Find all substations
MATCH (s) WHERE 'cim__Substation' IN labels(s)
RETURN s.`cim__IdentifiedObject.name` AS name;
```

---

## Adding SCADA / Protection / Network Overlays

After the CIM base graph is imported, add overlay layers:

```cypher
// Example: Link a SCADA point to a CIM Breaker
MATCH (b) WHERE 'cim__Breaker' IN labels(b)
  AND b.`cim__IdentifiedObject.name` = 'BRK_IEEE13_634'
CREATE (sp:SCADAPoint {
  tagName: 'SUB1.BRK634.STATUS',
  pointType: 'BINARY',
  source: 'RTAC',
  description: 'Breaker 634 status'
})
CREATE (sp)-[:MONITORS]->(b);

// Example: Protection relay association
CREATE (relay:ProtectionDevice {
  name: 'SEL-351S',
  function: '50/51',
  setting: 'Phase OC'
})
WITH relay
MATCH (b) WHERE 'cim__Breaker' IN labels(b)
  AND b.`cim__IdentifiedObject.name` = 'BRK_IEEE13_634'
CREATE (relay)-[:PROTECTS]->(b);
```

These overlays can be added via:
- **Neo4j Browser** — manual Cypher
- **Neo4j Bloom** — visual graph editing
- **SCADA Studio sidecar** — automated from RTAC config parsing
- **n8n workflows** — triggered by Gitea push webhooks

---

## Useful Cypher Queries

```cypher
// List all n10s namespace prefixes
CALL n10s.nsprefixes.list();

// Show graph config
CALL n10s.graphconfig.show();

// Delete all imported RDF data (keep overlays)
MATCH (n:Resource) DETACH DELETE n;

// Full database reset
MATCH (n) DETACH DELETE n;
CALL n10s.graphconfig.init({handleVocabUris:"SHORTEN", handleMultival:"ARRAY"});
```

---

## Plugins Installed

| Plugin | Purpose |
|--------|---------|
| **neosemantics (n10s)** | RDF import/export, SPARQL bridge, namespace handling |
| **APOC** | Utility procedures (text, collections, graph refactoring) |

---

## Troubleshooting

### n10s procedures not found
- Check JAR in `/var/lib/neo4j/plugins/`: `docker exec verance-neo4j ls /var/lib/neo4j/plugins/`
- Verify config: `CALL dbms.listConfig() YIELD name, value WHERE name CONTAINS 'unmanaged' RETURN *;`
- Check logs: `docker logs verance-neo4j | grep -i "n10s\|neosemantics\|plugin"`

### "Failed to invoke procedure n10s.graphconfig.init" 
- The unique constraint must exist first:
  ```cypher
  CREATE CONSTRAINT n10s_unique_uri IF NOT EXISTS FOR (r:Resource) REQUIRE r.uri IS UNIQUE;
  ```

### Import from Blazegraph returns 0 triples
- Verify Blazegraph is reachable: `curl http://blazegraph.railway.internal:8080/bigdata/namespace/kb/sparql?query=SELECT%20*%20WHERE%20{?s%20?p%20?o}%20LIMIT%201`
- Try fetching as different format: change `"Turtle"` to `"RDF/XML"`
- Check CORS / firewall between Railway services (internal network should be fine)

### Railway health check failing
- Neo4j takes 30-60s to start; healthcheckTimeout is set to 120s
- Check logs: `railway logs --service neo4j --tail 100`
