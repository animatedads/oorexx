/* Message instructions modify RESULT; expression messages do not. */
say 'initial' result
text = 'abc'
text~length
say 'length' result
text~~reverse
say 'cascade' result
value = text~copies(2)
say 'expression' value 'prior-result' result
text~reverse
say 'reverse' result
text~substr(2, 2)
say 'substr' result
text~~upper~length
say 'chained' result
say 'expression-cascade' text~~upper
say 'result-untouched' result
exit 0
