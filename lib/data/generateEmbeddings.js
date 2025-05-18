require('dotenv').config();
const { CohereClient } = require('cohere-ai');
const admin = require("firebase-admin");
const serviceAccount = require("./hackathon-app-project-firebase-adminsdk-fbsvc-e3a8a310bb.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

// Initialize the Cohere client
const cohere = new CohereClient({
  token: process.env.COHERE_API_KEY || 'JDp7pYv5N5561NBsRzN4YLFGGB3GgRaYwi3fBEox'
});

// Add delay function to avoid rate limiting
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function generateEmbeddings() {
  const snapshot = await db.collection('programs').get();
  console.log(`Processing ${snapshot.docs.length} documents...`);

  for (const doc of snapshot.docs) {
    const data = doc.data();

    if (data.embedding) {
      console.log(`✓ Embedding zaten var: ${data.title}`);
      continue; // zaten varsa atla
    }

    const inputText = `${data.title}. ${data.description}`;

    try {
      // Wait for 300ms before making the next request
      await delay(300);
      
      console.log(`Embedding oluşturuluyor: ${data.title}`);
      
      // Use Cohere's embed endpoint
      const response = await cohere.embed({
        texts: [inputText],
        model: "embed-english-v3.0",
        input_type: "search_document"
      });

      // Extract the embedding from the response
      const embedding = response.embeddings[0];

      await db.collection('programs').doc(doc.id).update({
        embedding: embedding
      });

      console.log(`✓ Embedding eklendi: ${data.title}`);
    } catch (err) {
      console.error(`⚠️ Hata (${data.title}):`, err.message);
      
      // If we get a rate limit error, wait longer
      if (err.message.includes('429') || err.message.includes('rate limit')) {
        console.log('Rate limit aşıldı, 2 saniye bekleniyor...');
        await delay(2000);
      }
    }
  }

  console.log("✅ Tüm embedding işlemleri tamamlandı.");
}

generateEmbeddings();
