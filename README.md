# J.A.R.V.I.S

![logo](./lib/logo.png)

An AI-RPA agent based on 

1. Computer Vision to understand computer screens, 
2. Selenium to operate such screens, 
3. SSH interface to interact with other systems, and
4. GPT to natural language instructions

## 1. Getting Started

1. Install the library.

```bash
gem install blackstack-jarvis
```

2. Create an instance of Jarvis.

```ruby
require 'blackstack-jarvis'

jarvis = BlackStack::Jarvis.new(
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

## 2. Operating with your local computer

Create a text file with a command like this:

```bash
echo -e 'What is the most impressive invention of Leonardo Davinci?' > ~/some.text
```

Then, you can refer Jarvis to such a file to find an instruction.

```ruby
p jarvis.q('I wrote some instructions in the file ~/jarvis.txt. Please read it and answer.')
# => "The most impressive invention of Leonardo Davinci is the the flying machine."
```

In the next sections, we'll store some information in files like passwords of SSH credentials. 

## 3. Operating with other computers

## 4. Operating with browsers

## 5. Operating with websites