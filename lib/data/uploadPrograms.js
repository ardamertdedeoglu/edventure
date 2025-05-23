const admin = require('firebase-admin');
const serviceAccount = require('./hackathon-app-project-firebase-adminsdk-fbsvc-ea16fa574e.json'); // Replace with your actual JSON file
const programs = require('./programs.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function uploadPrograms() {
  for (const program of programs) {
    await db.collection('programs').add(program);
    console.log(`Uploaded: ${program.title}`);
  }
  console.log("✅ All programs uploaded.");
}

uploadPrograms();
