// Use dotenv only in development
if (process.env.NODE_ENV !== 'production') {
  require('dotenv').config();
}

const { CohereClient } = require('cohere-ai');
const admin = require("firebase-admin");
const functions = require('firebase-functions');
const cors = require('cors')({ origin: true, credentials: true });

// Get the API key from Firebase Config or fallback to environment variable
const getCohereApiKey = () => {
  // Try to get from Firebase Config first (for production)
  try {
    return functions.config().cohere.apikey;
  } catch (e) {
    // Fallback to environment variable (for development)
    return process.env.COHERE_API_KEY || 'JDp7pYv5N5561NBsRzN4YLFGGB3GgRaYwi3fBEox';
  }
};

// Initialize the Cohere client with API key
const cohere = new CohereClient({
  token: getCohereApiKey()
});

// Initialize Firebase without a service account (uses default credentials in cloud environment)
admin.initializeApp();
const db = admin.firestore();

// Verify Firebase ID token
const verifyIdToken = async (idToken) => {
  if (!idToken) {
    throw new Error('No ID token provided');
  }
  
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    return decodedToken;
  } catch (error) {
    console.error('Error verifying ID token:', error);
    throw new Error('Invalid ID token');
  }
};

// Extract token from Authorization header
const extractToken = (req) => {
  if (!req.headers.authorization) {
    return null;
  }
  
  const authHeader = req.headers.authorization;
  if (!authHeader.startsWith('Bearer ')) {
    return null;
  }
  
  return authHeader.split('Bearer ')[1];
};

// Cosine similarity hesaplayan fonksiyon
function cosineSimilarity(vecA, vecB) {
  const dotProduct = vecA.reduce((sum, val, i) => sum + val * vecB[i], 0);
  const magnitudeA = Math.sqrt(vecA.reduce((sum, val) => sum + val * val, 0));
  const magnitudeB = Math.sqrt(vecB.reduce((sum, val) => sum + val * val, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}

// HTTP function with onRequest for semantic search
exports.semanticSearch = functions.https.onRequest((req, res) => {
  // Set CORS headers manually for preflight requests
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  // Handle preflight requests (OPTIONS method)
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  // Enable CORS
  return cors(req, res, async () => {
    try {
      // Check method
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method Not Allowed. Use POST.' });
      }

      // Log the request for debugging
      console.log('Request received:', req.body);
      
      // Extract and verify token
      const idToken = extractToken(req);
      
      if (!idToken) {
        return res.status(401).json({ error: 'Authentication required' });
      }
      
      try {
        const decodedToken = await verifyIdToken(idToken);
        console.log('Authenticated user:', decodedToken.uid);
      } catch (authError) {
        console.error('Authentication error:', authError);
        return res.status(403).json({ error: 'Invalid authentication' });
      }

      // Get query from request body
      const query = req.body.query;
      if (!query) {
        return res.status(400).json({ error: "Sorgu eksik" });
      }

      // Generate embeddings with Cohere
      const response = await cohere.embed({
        texts: [query],
        model: "embed-english-v3.0",
      });

      const queryEmbedding = response.body.embeddings[0];
      const snapshot = await db.collection("programs").get();

      const results = [];

      // Calculate similarity for each document
      snapshot.forEach((doc) => {
        const d = doc.data();
        if (!d.embedding) return;

        const sim = cosineSimilarity(queryEmbedding, d.embedding);
        results.push({
          id: doc.id,
          title: d.title,
          description: d.description,
          similarity: sim,
        });
      });

      // Sort results by similarity and return top 5
      results.sort((a, b) => b.similarity - a.similarity);
      return res.status(200).json({ results: results.slice(0, 5) });
    } catch (error) {
      console.error("Error in semantic search:", error);
      return res.status(500).json({ error: error.message });
    }
  });
});

// Health check endpoint
exports.healthCheck = functions.https.onRequest((req, res) => {
  // Set CORS headers manually
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET');
  
  return cors(req, res, async () => {
    res.status(200).send('OK');
  });
});
