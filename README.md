# J.A.R.V.I.S

![logo](./lib/logo.png)

An AI-RPA agent based on 

1. Computer Vision to understand computer screens, 
2. Selenium to operate such screens, 
3. SSH interface to interact with other systems, and
4. GPT to natural language instructions

## Installation

```bash
gem install blackstack-jarvis
```

## Getting Started

```ruby
require 'blackstack-jarvis'

j = BlackStack::Jarvis.new(
    # ths is to connect with your OpenAI account.
    # reference: https://platform.openai.com/docs/api-reference/authentication
    openai_api_key: '<your open AI api key here>',
    openai_model: 'gpt-4-1106-preview',
    
    # this is to operate browsers using AdsPower.
    # reference: https://github.com/leandrosardi/adspower-client    
    adspower_api_key: '<your adspower api key heere>',
    
    # this is to use dropbox as a cloud storage of screenshots, audios and text files.
    # reference: https://github.com/leandrosardi/my-dropbox-api
    dropbox_refresh_token: '<your dropbox refresh token here>',
)
```

