// assets/js/web_search_agent.js

// Helper to make HTTP requests.
// In the context of flutter_js, `fetch` is typically available.
async function makeRequest(url, method = 'GET', body = null, headers = {}) {
    const options = { method, headers };
    if (body) {
        options.body = JSON.stringify(body);
        // Ensure Content-Type is set for POST requests with a body
        if (!headers['Content-Type']) {
            headers['Content-Type'] = 'application/json';
        }
    }
    options.headers = headers; // Re-assign headers after potential modification

    console.log(`Making ${method} request to ${url} with options: ${JSON.stringify(options)}`);

    const response = await fetch(url, options);
    
    const responseBodyText = await response.text(); // Read body once for logging or error
    console.log(`Response Status: ${response.status}`);
    console.log(`Response Body: ${responseBodyText}`);

    if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}, body: ${responseBodyText}`);
    }
    try {
        return JSON.parse(responseBodyText); // Try to parse as JSON
    } catch (e) {
        // If not JSON, it might be an error or an unexpected response type.
        // For some APIs, a successful non-JSON response might occur, but typically we expect JSON.
        console.warn("Response was not JSON, returning raw text. This might be an error or unexpected for JSON-expecting parts of the code.");
        return responseBodyText; // Or handle as an error more strictly
    }
}

async function getRecommendationsFromWeb(userPrompt, googleApiKey, googleCx, openaiApiKey) {
    console.log("JS: getRecommendationsFromWeb called with prompt: " + userPrompt);
    try {
        // 1. Call Google Custom Search API
        const searchQuery = `${userPrompt} work and travel programs`; // Make search query more specific
        const searchUrl = `https://www.googleapis.com/customsearch/v1?key=${googleApiKey}&cx=${googleCx}&q=${encodeURIComponent(searchQuery)}&num=5`; // Get 5 results
        
        console.log("JS: Calling Google Search API: " + searchUrl);
        const searchResults = await makeRequest(searchUrl);
        console.log("JS: Google Search API response received.");

        let snippets = "No relevant search results found from Google Custom Search.";
        if (searchResults && searchResults.items && searchResults.items.length > 0) {
            snippets = searchResults.items.map(item => {
                return `Title: ${item.title}\nSnippet: ${item.snippet}\nLink: ${item.link}`;
            }).join('\n\n---\n\n'); // Escaped newlines for JSON string within JS, then for Dart string
        } else {
            console.log("JS: No items found in Google Search results or results structure is unexpected.");
        }
        console.log("JS: Snippets for OpenAI: " + snippets);

        // 2. Call OpenAI API to process search results and generate recommendations
        const openaiUrl = "https://api.openai.com/v1/chat/completions";
        const systemPrompt = `You are a Work & Travel program expert. Based on the user's request and the provided web search results, generate up to 3 travel program recommendations.
Format your response as a JSON list with the following structure for each program:
[
  {
    "title": "Program Title",
    "location": "Country, City (e.g., USA, Los Angeles)",
    "duration": "Program duration (e.g., 3 months)",
    "cost": "Cost with currency (e.g., 3000 USD)",
    "description": "Program description (concise, max 250 characters)",
    "features": ["Feature 1", "Feature 2", "Feature 3 (related to work & travel)"],
    "image_url": "Use one of the following based on location: USA_IMAGE_URL, CANADA_IMAGE_URL, AUSTRALIA_IMAGE_URL, EUROPE_IMAGE_URL, ASIA_IMAGE_URL, DEFAULT_IMAGE_URL. Replace these placeholders with actual HTTPS URLs."
  }
]
Replace USA_IMAGE_URL with 'https://images.unsplash.com/photo-1501594907352-04cda38ebc29',
CANADA_IMAGE_URL with 'https://images.unsplash.com/photo-1503614472-8c93d56e92ce',
AUSTRALIA_IMAGE_URL with 'https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9',
EUROPE_IMAGE_URL with 'https://images.unsplash.com/photo-1490642914619-7955a3fd483c',
ASIA_IMAGE_URL with 'https://images.unsplash.com/photo-1493780474015-ba834fd0ce2f',
DEFAULT_IMAGE_URL with 'https://images.unsplash.com/photo-1507608616759-54f48f0af0ee'.
Ensure the output is ONLY the JSON list. If no suitable programs can be derived from the information, return an empty list [].
Prioritize information from the web search snippets. If specific details (like cost, duration, features) are not in the snippets, you can make reasonable estimations based on the type of program and location, or state 'Not specified'.
Be concise with descriptions and features. Features should be relevant to a work and travel experience.`;
        
        const userMessageContent = `User Request: "${userPrompt}"\n\nWeb Search Results (Snippets):\n${snippets}`;
        
        const openaiPayload = {
            "model": "gpt-4", // or "gpt-3.5-turbo" for faster/cheaper, "gpt-4-turbo-preview"
            "messages": [
                {
                    "role": "system",
                    "content": systemPrompt
                },
                {
                    "role": "user",
                    "content": userMessageContent
                }
            ],
            "temperature": 0.5, // Lower for more factual, higher for more creative
            "max_tokens": 2500, // Adjusted for potentially larger JSON with 3 items
            "response_format": { "type": "json_object" } // Request JSON output if using compatible models
        };

        const openaiHeaders = {
            'Authorization': `Bearer ${openaiApiKey}`,
            'Content-Type': 'application/json'
        };
        
        console.log("JS: Calling OpenAI API.");
        // console.log("JS: OpenAI Payload: " + JSON.stringify(openaiPayload)); // Can be very verbose

        const openaiResponseData = await makeRequest(openaiUrl, 'POST', openaiPayload, openaiHeaders);
        console.log("JS: OpenAI API response received.");

        let llmOutput = "[]"; // Default to empty list string

        if (openaiResponseData && openaiResponseData.choices && openaiResponseData.choices.length > 0 && openaiResponseData.choices[0].message && openaiResponseData.choices[0].message.content) {
            llmOutput = openaiResponseData.choices[0].message.content;
            console.log("JS: LLM raw output: " + llmOutput);
        } else {
            console.error("JS: OpenAI response structure was not as expected:", JSON.stringify(openaiResponseData));
            throw new Error("Invalid response structure from OpenAI.");
        }
        
        // LLM output is expected to be a JSON string.
        // The prompt asks for "ONLY the JSON list", and with response_format: { "type": "json_object" }
        // it should ideally be clean JSON. If it's wrapped in markdown, that's an issue.
        // The 'json_object' type might return a JSON object string, not necessarily a list string directly.
        // The prompt specifically asks for a JSON list: "[ { ... } ]"
        // If the LLM returns a JSON object like { "recommendations": [ ... ] }, the prompt needs adjustment or parsing here.
        // For now, assuming the LLM adheres to "ONLY THE JSON LIST" part of the prompt.

        // Basic cleaning, though `response_format: { "type": "json_object" }` should reduce need for this.
        llmOutput = llmOutput.trim();
        if (llmOutput.startsWith("```json")) {
            llmOutput = llmOutput.substring(7);
            if (llmOutput.endsWith("```")) {
                llmOutput = llmOutput.substring(0, llmOutput.length - 3);
            }
            llmOutput = llmOutput.trim();
        }
        
        // Validate if it's a valid JSON string before returning
        try {
            JSON.parse(llmOutput);
        } catch (parseError) {
            console.error("JS: LLM output is not valid JSON after cleaning: " + llmOutput, parseError);
            // Fallback to returning an empty list string if LLM output is not parseable JSON
            return "[]";
        }
        
        console.log("JS: Returning final JSON string to Dart: " + llmOutput);
        return llmOutput;

    } catch (error) {
        // Log the detailed error object
        console.error("JS: Error in getRecommendationsFromWeb:", error);
        // Check if error has a message property, common in JavaScript Error objects
        const errorMessage = error.message ? error.message : error.toString();
        console.error("JS: Error message: " + errorMessage);
        // If error has a stack property, log that too for more context
        if (error.stack) {
            console.error("JS: Error stack: " + error.stack);
        }
        return "[]"; // Return an empty list as a string in case of error
    }
} 