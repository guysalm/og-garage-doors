/**
 * Daily: deletes chat transcripts older than RETAIN_DAYS from the Netlify Blobs
 * store "chat-transcripts". Visitors type names, phone numbers and addresses,
 * so conversations are not kept forever. Keys start with the day the chat
 * began ("YYYY-MM-DD/<random>", see chat.mts), so age is read from the key.
 */
import { getStore } from "@netlify/blobs";

const RETAIN_DAYS = 90;

export default async (): Promise<void> => {
  const store = getStore("chat-transcripts");
  const cutoff = new Date(Date.now() - RETAIN_DAYS * 86_400_000).toISOString().slice(0, 10);
  let deleted = 0;
  for await (const page of store.list({ paginate: true })) {
    for (const blob of page.blobs) {
      const day = blob.key.slice(0, 10);
      if (/^\d{4}-\d{2}-\d{2}$/.test(day) && day < cutoff) {
        await store.delete(blob.key);
        deleted++;
      }
    }
  }
  console.log(`[chat-cleanup] deleted ${deleted} transcript(s) started before ${cutoff}`);
};

export const config = { schedule: "@daily" };
