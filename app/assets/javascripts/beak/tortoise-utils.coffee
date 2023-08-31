markdownToHtml = (md) ->
  # html_sanitize is provided by Google Caja - see https://code.google.com/p/google-caja/wiki/JsHtmlSanitizer
  # RG 8/18/15
  window.html_sanitize(
    window.markdown.toHTML(md),
    (url) -> if /^https?:\/\//.test(url) then url else undefined, # URL Sanitizer
    (id) -> id)                                                   # ID Sanitizer

# (String) => String
toNetLogoWebMarkdown = (md) ->
  md.replace(
    new RegExp('<!---*\\s*((?:[^-]|-+[^->])*)\\s*-*-->', 'g')
    (match, commentText) ->
      "[nlw-comment]: <> (#{commentText.trim()})")

# (String) => String
toNetLogoMarkdown = (md) ->
  md.replace(
    new RegExp('\\[nlw-comment\\]: <> \\(([^\\)]*)\\)', 'g'),
    (match, commentText) ->
      "<!-- #{commentText} -->")

# Given a string, returns how that string would look if represented in the NetLogo language.
# For example, the string "Hello \"world!\"\n" would be replaced with "\"Hello \\\"world!\\\"\\n".
# (string) -> string
toNetLogoString = (input) ->
  sanitized = input.replace(/[\n\t\"\\]/g, (match) ->
    switch match
      when "\n" then "\\n"
      when "\t" then "\\t"
      when "\"" then "\\\""
      when "\\" then "\\\\"
      else match
  )
  "\"#{sanitized}\""

# (String) => String
normalizedFileName = (path) ->
# We separate on both / and \ because we get URLs and Windows-esque filepaths
  pathComponents = path.split(/\/|\\/)
  decodeURI(pathComponents[pathComponents.length - 1])

# (String) => Array[String]
nlogoToSections = (nlogo) ->
  nlogo.split(/^\@#\$#\@#\$#\@$/gm)

# (Array[String]) => String
sectionsToNlogo = (sections) ->
  sections.join('@#$#@#$#@')

export {
  markdownToHtml,
  toNetLogoWebMarkdown,
  toNetLogoMarkdown,
  toNetLogoString
  normalizedFileName,
  nlogoToSections,
  sectionsToNlogo
}
