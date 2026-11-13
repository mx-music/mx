// Renders ```mermaid code blocks as diagrams, loading beautiful-mermaid only on pages that have one
const MERMAID_URL = "https://cdn.jsdelivr.net/npm/beautiful-mermaid@1.1.3/+esm"

// ExDoc's own colors, so diagrams follow its light and dark themes without re-rendering
const COLORS = { bg: "var(--background)", fg: "var(--textBody)", accent: "var(--main)", transparent: true }

let renderer

window.addEventListener("exdoc:loaded", async () => {
  const blocks = document.querySelectorAll("pre code.mermaid")
  if (blocks.length === 0) return

  renderer ??= import(MERMAID_URL)
  const { renderMermaidSVG } = await renderer

  blocks.forEach((code) => {
    const figure = document.createElement("figure")
    figure.className = "mermaid-diagram"
    figure.innerHTML = renderMermaidSVG(code.textContent, COLORS)
    code.parentElement.replaceWith(figure)
  })
})
