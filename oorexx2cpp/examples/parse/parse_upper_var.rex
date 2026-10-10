s = 'aBc Def'
parse upper var s before 'B' after
say before
say after
parse lower var s first rest
say first
say rest
parse upper value 'one|tWo' with first '|' second
say first
say second
