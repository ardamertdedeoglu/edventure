# Firebase Functions for Semantic Search

This directory contains Firebase Cloud Functions for semantic search functionality using Cohere AI embeddings.

## Setup and Deployment

1. Install dependencies:
```
npm install
```

2. Set up environment variables in Firebase:
```
firebase functions:config:set cohere.apikey="YOUR_COHERE_API_KEY"
```

3. Deploy the functions:
```
firebase deploy --only functions
```

## Local Development

1. Create a `.env` file with your Cohere API key:
```
COHERE_API_KEY=your_cohere_api_key_here
NODE_ENV=development
```

2. Run the function locally:
```
npm run serve
```

## Troubleshooting

If you encounter any deployment errors:

1. Make sure the `firebase-admin` initialization doesn't use a service account in production
2. Set environment variables properly using Firebase Config
3. Check that all dependencies are listed in package.json
4. Ensure the runtime version is set to `nodejs18` in firebase.json 