// Stdin reading utility

export async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  
  return new Promise((resolve, reject) => {
    process.stdin.on('data', (chunk) => chunks.push(chunk));
    process.stdin.on('end', () => resolve(Buffer.concat(chunks).toString()));
    process.stdin.on('error', reject);
  });
}