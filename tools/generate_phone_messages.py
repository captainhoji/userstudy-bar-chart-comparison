import csv
import os
import random
import time
from typing import List, Dict

from openai import OpenAI

MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
OUTPUT_CSV = os.getenv("OUTPUT_CSV", "/Users/jihokim/Desktop/userStudy/static/phone_messages.csv")

SEED = int(os.getenv("SEED", "23"))
CHUNKS = int(os.getenv("CHUNKS", "20"))
LINES_PER_CHUNK = int(os.getenv("LINES_PER_CHUNK", "20"))
PET_MENTION_PROB = float(os.getenv("PET_MENTION_PROB", "0.35"))

SENDERS = ["Alex", "Maya", "Sam", "Jordan"]
PET_OWNER = {
    "Alex": "dog",
    "Sam": "cat",
    "Jordan": "parrot",
    "Maya": "goldfish",
}

TOPICS = [
    "coming to a party",
    "job interview prep",
    "bad weather plans",
    "brunch plans",
    "group project meeting",
    "gym plans",
    "campus fair",
    "library study session",
    "dinner plans",
    "presentation practice",
    "game night",
    "grocery run",
    "weekend plans",
    "career fair",
    "study group",
    "coffee meetup",
    "advisor meeting",
    "night market",
    "project conflict",
    "concert plans",
]

SYSTEM_PROMPT = """
You are writing short, natural group chat messages between four college friends.
Each conversation chunk has a central non-pet topic supplied by the user.
Tone: lively, casual, realistic college friend group. No profanity. No emojis unless prompted.
Messages should be 5-14 words and flow naturally from prior messages in the chunk.
Avoid repeated phrasing within a chunk.
""".strip()

USER_PROMPT = """
Topic: {topic}
Sender: {sender}
Pet owner: {pet_owner}
Requirement: {requirement}
Recent context:
{context}

Write ONE chat message (just the message text) that fits the topic and context.
If requirement says PET, the message must clearly be about the sender's pet (but do not mention the animal name explicitly).
If requirement says NO PET, do not mention pets.
""".strip()


client = OpenAI()


def backoff_sleep(attempt: int) -> None:
    time.sleep(min(2 ** attempt, 8) + random.random())


def generate_message(topic: str, sender: str, require_pet: bool, context: List[Dict[str, str]]) -> str:
    requirement = "PET" if require_pet else "NO PET"
    ctx_lines = [f"{m['sender']}: {m['text']}" for m in context[-6:]]
    ctx_text = "\n".join(ctx_lines) if ctx_lines else "(no prior messages)"

    prompt = USER_PROMPT.format(
        topic=topic,
        sender=sender,
        pet_owner=PET_OWNER[sender],
        requirement=requirement,
        context=ctx_text,
    )

    for attempt in range(5):
        try:
            resp = client.responses.create(
                model=MODEL,
                input=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": prompt},
                ],
                max_output_tokens=60,
            )
            text = resp.output_text.strip()
            return text
        except Exception:
            backoff_sleep(attempt)
    raise RuntimeError("Failed to generate message after retries")


def main() -> None:
    random.seed(SEED)

    if len(TOPICS) < CHUNKS:
        raise ValueError("TOPICS must contain at least CHUNKS items")

    rows = []
    for chunk_idx in range(CHUNKS):
        chunk_id = f"convo_{chunk_idx + 1:02d}"
        topic = TOPICS[chunk_idx]
        context: List[Dict[str, str]] = []

        for i in range(LINES_PER_CHUNK):
            sender = SENDERS[i % len(SENDERS)]
            require_pet = random.random() < PET_MENTION_PROB
            text = generate_message(topic, sender, require_pet, context)
            rows.append([chunk_id, sender, text, "yes" if require_pet else "no"])
            context.append({"sender": sender, "text": text})

    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["chunk_id", "sender", "text", "pet_mention"])
        writer.writerows(rows)

    print(f"Wrote {len(rows)} rows to {OUTPUT_CSV}")


if __name__ == "__main__":
    main()
