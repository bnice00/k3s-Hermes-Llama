import requests
import os
import streamlit as st 
import uuid
URL = os.environ.get("HERMES_URL","http://hermes-serve.hermes-lair.svc.cluster.local.:8642/v1/chat/completions")
API_KEY= os.environ.get("HERMES_API_KEY")
MODEL = "hermes-agent"
if "messages" not in st.session_state:
   st.session_state.messages = []   # <-- this list IS the conversation. Nothing else remembers.

if "sessionID" not in st.session_state:
   st.session_state.sessionID = str(uuid.uuid4())

def chat(user_input):
    HEADERS = {
    "Content-Type": "application/json",
    "X-Hermes-Session-Id": st.session_state.sessionID,
    "Authorization": f"Bearer {API_KEY}",
    }    
    st.session_state.messages.append({"role": "user", "content": user_input})

# POST to URL with json={"model": MODEL, "messages": messages}
    r = requests.post(
        URL, 
        headers=HEADERS, 
        json={"model":MODEL,"messages":[{"role": "user", "content": user_input}]})
    data = r.json()

    # 3. dig the reply out of the response
    reply= data["choices"][0]["message"]["content"]

    st.session_state.messages.append({"role":"assistant", "content":reply, "tokens": data["usage"]["prompt_tokens"]})
    
    return reply

for message in st.session_state.messages:
    with st.chat_message(message["role"]):
         st.markdown(message["content"])
         if message.get("tokens"):
             st.caption(f"{message['tokens']} tokens")
if prompt := st.chat_input("Ask anything..."):
    chat(prompt)
    st.rerun()