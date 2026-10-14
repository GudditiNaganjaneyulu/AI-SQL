# AI Concepts for SQL Developers

> **Objective (part):** *Evaluate external models, including multimodal, multilanguage, sizes, and structured output.* This chapter also gives you the vocabulary for the rest of Domain 3.

## Models you'll use

| Model type | Input → output | Used for |
|---|---|---|
| **Embedding model** | Text (or image) → **vector** of numbers | Semantic search, similarity, clustering, RAG retrieval |
| **Chat / completion model (LLM)** | Prompt (instructions + context + question) → text or JSON | Answering questions, summarizing, classifying, extracting |

Examples: `text-embedding-3-small` / `text-embedding-3-large` (embeddings) and GPT-family chat models, hosted in **Azure OpenAI in Microsoft Foundry**, OpenAI, or locally (e.g., **Ollama**, **ONNX Runtime** on SQL Server).

## Embeddings and vectors

An **embedding** is a list of numbers (a **vector**) that represents the **meaning** of a piece of content. Similar meanings → vectors close together.

```
"lightweight two-person tent"   → [0.021, -0.113, 0.087, …]  (e.g., 1,536 numbers)
"ultralight backpacking shelter" → [0.019, -0.108, 0.091, …]  ← close
"cast-iron frying pan"           → [-0.204, 0.055, -0.010, …] ← far
```

- **Dimensions** = how many numbers. Each model has a fixed (sometimes configurable) dimension count, e.g., 1,536.
- You must **embed the query with the same model** used for the stored data. Vectors from different models are not comparable.

## Measuring "closeness"

| Metric | Intuition | In SQL |
|---|---|---|
| **Cosine distance** | Angle between vectors (ignores length). Range 0 (same direction) to 2 (opposite) | `'cosine'` — the usual choice for text embeddings |
| **Euclidean distance** | Straight-line distance | `'euclidean'` |
| **Dot product** | Combines angle and length. SQL returns the **negative** dot product so that **smaller = more similar** | `'dot'` |

For **normalized** vectors (length 1), cosine and dot product give the same ranking. Many embedding models (including OpenAI's) return normalized vectors.

## Exact (KNN) vs approximate (ANN) search

| | **KNN** — k-nearest neighbours (exact) | **ANN** — approximate nearest neighbours |
|---|---|---|
| How | Compare the query with **every** vector | Use an index (e.g., **DiskANN** graph) to visit only promising candidates |
| Accuracy (recall) | 100% | Very high but < 100% |
| Speed at scale | Slows linearly with rows | Fast on millions of vectors |
| SQL | `VECTOR_DISTANCE` + `ORDER BY` (or `VECTOR_SEARCH` without `APPROXIMATE`) | `CREATE VECTOR INDEX` + `SELECT TOP (n) WITH APPROXIMATE … VECTOR_SEARCH(…)` |
| When | Small tables (up to tens of thousands of rows), or heavily pre-filtered sets | Large tables, latency-sensitive apps |

## Tokens and context windows

Models process **tokens** (word pieces; roughly ¾ of an English word). Every model has a maximum **context window** (input + output tokens). This is why we:

- **Chunk** long documents before embedding them.
- Send only the **top few relevant chunks** to the chat model in RAG.

## Retrieval-augmented generation (RAG)

LLMs don't know your private data and can **hallucinate**. RAG fixes that:

```
1. Question  ─► embed ─► vector search your data ─► top-k relevant rows/chunks
2. Build a prompt: instructions + retrieved context (JSON) + question
3. Send to chat model ─► grounded answer (ideally with citations)
```

## Evaluating external models (exam objective)

| Factor | Questions to ask |
|---|---|
| **Task fit** | Embeddings vs chat? Do you need reasoning or just retrieval? |
| **Multimodal** | Must it handle images/audio as well as text (e.g., product photos)? Choose a multimodal model and store embeddings in the same vector space |
| **Multilanguage** | Are documents/queries in many languages? Choose a multilingual embedding model so a Hindi query can match English content |
| **Size & dimensions** | Larger models/dimensions → often better quality but **more storage, slower search, higher cost**. Some models let you request fewer dimensions (`"dimensions": 768`) |
| **Max input length** | Determines chunk size |
| **Structured output** | Can the chat model return **JSON that conforms to a schema** (e.g., `response_format` with a JSON schema)? Essential when SQL must parse the answer reliably |
| **Latency, throughput, cost** | Tokens per minute quotas, price per 1K tokens |
| **Hosting & compliance** | Data residency, private networking, managed identity support, content filtering |
| **Local vs cloud** | Local (Ollama/ONNX) keeps data on-prem; cloud gives stronger models |

> **Storage math:** `vector(1536)` with float32 = 1,536 × 4 bytes ≈ **6 KB per row**. One million rows ≈ 6 GB just for vectors. `float16` halves that.

## Knowledge check

1. Why must the query be embedded with the same model as the stored data?
2. Which metric does SQL return as a *negative* value so that smaller means closer?
3. When is exact KNN search an acceptable choice?
4. What model capability lets SQL reliably parse a chat model's answer?

<details>
<summary>Answers</summary>

1. Different models produce vectors in different spaces; distances between them are meaningless.
2. Dot product (`'dot'`).
3. When the candidate set is small (small table or strong pre-filtering) and 100% recall matters.
4. Structured output (JSON conforming to a schema).
</details>
