---
name: translate
description: 渡した文を日本語か英語に翻訳する。`-j` で日本語へ、`-e` で英語へ訳す。どちらも無ければ原文と逆の言語（日本語なら英語、それ以外なら日本語）へ訳す。
argument-hint: "[-j | -e] <翻訳する文>"
disable-model-invocation: true
---

# translate

Read a leading `-j` or `-e` in `$ARGUMENTS` as the target language (`-j`: Japanese, `-e`: English). Everything after it is the source text. Without a flag, translate Japanese source into English and anything else into Japanese. A `-j` or `-e` appearing later in the text is part of the source.

## Fidelity

- Preserve meaning accurately.
- Do not omit, add, summarize, reinterpret, or correct content.
- Maintain the original tone and register (formality, stiffness, technicality).
- Do not change perspective or voice (both grammatical voice and the author's voice).
- Ensure terminology consistency. Use the established translation where one exists.
- Preserve numbers, dates, legal citations, and proper nouns exactly. Keep their values, and write them in the target language's conventions (e.g. 民法第709条 -> Article 709 of the Civil Code). For a proper noun with no established rendering, give the original alongside.
- Leave code, commands, identifiers, URLs, file paths, and Markdown syntax untranslated.
- Do not include explanations inside the translation. Use [Notes] if needed.

## Where fidelity rules collide

The structure of the target language sometimes forces a choice. Resolve it as below and record the choice in [Notes].

- Japanese to English: supply only the subjects and articles that English grammar requires. If the omitted subject is unclear from context, state which one you chose.
- English to Japanese: choose 敬体 or 常体 from the source's register. If the source does not settle it, state your choice.
- Errors in the source (typos, inconsistent figures): translate them as written and flag them. Do not fix them.
- Ambiguity: keep the ambiguity if the target language allows it. Otherwise take the most likely reading and list the alternative.

## Output format

```text
[Translation]
<translated text>

[Notes]
- Key terminology and translation decisions
- Brief notes on ambiguous or culturally specific terms (if any)
```

Write [Notes] in Japanese. Omit [Notes] if there are no significant translation decisions.
