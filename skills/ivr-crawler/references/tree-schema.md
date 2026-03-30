---
name: "references"
description: "Twilio development skill: references"
---

# IvrTree JSON Schema Reference

The crawler outputs an `IvrTree` JSON file with this structure:

## Top-Level Fields

```typescript
interface IvrTree {
  targetNumber: string;          // E.164 phone number crawled
  fromNumber: string;            // Caller ID used
  crawlStartedAt: string;        // ISO 8601 timestamp
  crawlCompletedAt: string;      // ISO 8601 timestamp
  totalCalls: number;            // Outbound calls made
  totalNodes: number;            // Nodes discovered
  maxDepthReached: number;       // Deepest level explored
  languages: string[];           // All languages detected
  rootNodeId: string;            // Always "root"
  nodes: Record<string, IvrNode>; // All nodes keyed by ID
}
```

## Node Structure

```typescript
interface IvrNode {
  id: string;                    // Path-based: "root", "1", "1-2", "1-2-3"
  path: string[];                // Digit sequence: [], ["1"], ["1","2"]
  nodeType: IvrNodeType;         // Classification (see below)
  promptText: string;            // Full transcribed prompt
  language: string;              // "en", "es", "fr", etc.
  edges: IvrEdge[];              // Outgoing options (empty for leaves)
  metadata: {
    confidence: number;          // 0-1 from Claude analysis
    callSid: string;             // Twilio call that discovered this
    discoveredAt: string;        // ISO 8601
    promptDurationMs: number;    // Time from call to prompt resolution
    retryCount: number;          // Call attempts for this node
  };
}
```

## Edge Structure

```typescript
interface IvrEdge {
  digit: string;                 // DTMF digit ("1", "0", "*", "#")
  label: string;                 // Human label ("Sales", "Support")
  speechKeywords: string[];      // Speech alternatives detected
  targetNodeId: string;          // Points to child IvrNode.id
  explored: boolean;             // Has this branch been crawled?
}
```

## Node Types

| Type | Description | Typical Edges |
|------|-------------|---------------|
| `root` | Entry point / language selection | Multiple |
| `menu` | Presents DTMF/speech options | Multiple |
| `information` | Plays info (hours, address, status) | 0 or redirect |
| `transfer` | Connects to live agent | 0 |
| `dead_end` | Final message then hangup | 0 |
| `callback` | Offers callback recording | 0-2 |
| `hold_music` | Hold music playing | 0 |
| `hours_check` | Business hours announcement | 0 |
| `voicemail` | Leave a message prompt | 0 |
| `error` | Crawl error at this node | 0 |
| `timeout` | No prompt received | 0 |
| `unknown` | Could not classify | 0 |

## Node ID Convention

- Root: `"root"`
- First level: `"1"`, `"2"`, `"3"`
- Second level: `"1-1"`, `"1-2"`, `"2-1"`
- Third level: `"1-1-1"`, `"1-2-3"`
- Pattern: digit path joined with `-`
