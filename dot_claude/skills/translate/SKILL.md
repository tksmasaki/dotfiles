---
name: translate
description: 渡した文を日本語か英語に翻訳する。`-j` で日本語へ、`-e` で英語へ訳す。どちらも無ければ原文と逆の言語（日本語なら英語、それ以外なら日本語）へ訳す。`--md` で訳文を md ファイルに書き出す。文の代わりに URL を渡すと、そのページの本文を訳す。
argument-hint: "[-j | -e] [--md] <翻訳する文 | URL>"
disable-model-invocation: true
---

# translate

Read the leading flags in `$ARGUMENTS`, in any order. `-j` or `-e` sets the target language (`-j`: Japanese, `-e`: English). `--md` writes the result to a Markdown file (see "Markdown output"). Everything after the flags is the source text. Without `-j` or `-e`, translate Japanese source into English and anything else into Japanese. A flag appearing later in the text is part of the source.

## URL source

When the source is a single URL and nothing else, translate the article body of that page. Get the page's own content, never a summary of it. Do not use WebFetch: it returns a model's answer about the page, not the page.

1. Fetch the raw HTML with `curl -sL`. Use it when the article body is in the HTML.
2. If curl fails, or the body is not in the HTML (rendered by JavaScript, a login wall, a bot check), open the URL in Chrome with the claude-in-chrome tools and read the rendered page. Do not read cookies or web storage.
3. If Chrome cannot show the body either, stop. Tell the user which methods failed and why, and do not translate from memory or from a partial page.

Translate the body only. Leave out site navigation, sidebars, comments, and share buttons. Keep the article's links, images, headings, quotations, and tables, and carry their URLs into the translation as Markdown links, resolving relative URLs against the page URL. State the page URL, and the author and date when the page gives them, at the top of the translation.

## Fidelity

- Preserve meaning accurately.
- Do not omit, add, summarize, reinterpret, or correct content.
- Maintain the original tone and register (formality, stiffness, technicality).
- Do not change perspective or voice (both grammatical voice and the author's voice).
- Ensure terminology consistency. Use the established translation where one exists.
- Preserve numbers, dates, and legal citations exactly. Keep their values, and write them in the target language's conventions (e.g. 民法第709条 -> Article 709 of the Civil Code).
- Preserve proper nouns exactly. Render them in their established form; if none exists, give the original alongside.
- Leave code, commands, identifiers, URLs, file paths, and Markdown syntax untranslated. Translate comments inside code, but not the code itself.
- Do not include explanations inside the translation. Use [Notes] if needed.

## Where fidelity rules collide

The structure of the target language sometimes forces a choice. Resolve it as below. Anything you state, flag, or list goes in [Notes].

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

Do not wrap the output in a code block. Write [Notes] in Japanese. Omit [Notes] if there are no significant translation decisions.

## Markdown output

With `--md`, write the translation to a file instead of the chat. Load the `md-output` skill and follow it for the output directory, the file name, and the chat reply after writing.

- Restore the source's structure as Markdown: the title as `#`, section headings as `##`, block quotations as `>`, lists, and tables. Change only the markup, never the wording of the translation.
- Leave out the `[Translation]` label.
- Put the [Notes] content in a final `## 訳注` section after a `---` rule. Write it in 常体, or in 敬体 when the translation into Japanese uses 敬体. Omit the section when [Notes] would be omitted.
