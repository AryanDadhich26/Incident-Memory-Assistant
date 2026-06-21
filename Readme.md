# Incident Memory Assistant

An incident response system that actually remembers. Most alerting tools tell you something broke. They don't tell you if your team has seen this exact problem before, or how it got fixed last time. That knowledge usually lives in someone's head, or buried three pages deep in a wiki nobody opens during an actual fire. This project closes that gap.

## What it does

When an alert comes in, the system embeds the alert text into a vector, searches a database of past resolved incidents for the closest semantic match, and asks an LLM to write a short, practical briefing: what's likely happening, the most similar incident on record, and a suggested first step. That briefing lands in Slack within a few seconds.

Once the incident is actually resolved, the resolution gets logged back into the same system. It's embedded too, and added to memory. So the next time something similar happens, this incident is part of what gets searched against. The system gets a little smarter every time it's used.

## Why semantic search instead of keyword matching

A keyword search would miss the connection between "checkout service container keeps crashing with OOMKilled status" and "search-api pods restarting repeatedly due to out of memory errors." Same underlying problem, almost no shared words. Embeddings catch that. This was actually tested directly: a new OOM-style alert worded completely differently than any stored incident still correctly ranked the right past incident as the closest match.

## Architecture
New alert

-> Webhook

-> Embed text (HuggingFace, BAAI/bge-small-en-v1.5)

-> Search past incidents by cosine similarity (Postgres + pgvector)

-> Keep the top match

-> LLM writes a briefing (Groq, Llama 3.3 70B)

-> Post to Slack
Resolved incident

-> Webhook

-> Embed text

-> Write back into the incidents table

-> Confirm in Slack

Both flows share a single webhook entry point, routed by an event type field, so there's one URL to manage instead of two.

## Stack

- n8n for orchestration
- PostgreSQL with the pgvector extension (hosted on Supabase) as the vector memory store
- HuggingFace Inference API for embeddings
- Groq for fast LLM inference
- Slack for delivery and confirmation

## A note on the build process

This wasn't a smooth, linear build, and I think that's worth being upfront about. The hardest part wasn't writing the embedding call or the Postgres query, it was a bug where a similarity search would silently return zero rows with no error message, across several layers at once. The query worked when tested alone, worked with a WHERE clause alone, worked with the SELECT arithmetic alone, but failed the moment ORDER BY was added.

Eventually traced it down using EXPLAIN ANALYZE, which proved Postgres was actually returning the row correctly. The real issue turned out to be a stale results cache in the SQL editor's UI, not the query at all. That kind of methodical, one-variable-at-a-time isolation, and learning not to trust a UI that says "no rows" without checking the underlying engine, ended up being the most useful part of building this.

## Setup

1. Create a Postgres database with the pgvector extension enabled
2. Run `db/schema.sql` to create the incidents table
3. Import `workflow/incident-memory-assistant.json` into n8n
4. Add your own credentials for HuggingFace, Groq, Postgres, and Slack
5. Set a webhook secret header for basic auth on the trigger
6. Send a test alert to the webhook and watch it land in Slack

## n8n
![worflow](Incident-Memory-Assistant/n8n.png)



