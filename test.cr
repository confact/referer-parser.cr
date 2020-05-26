require "./src/referer-parser.cr"


parser = RefererParser::Parser.new
result = parser.parse("http://www.google.com/search?q=gateway+oracle+cards+denise+linn&hl=en&client=safari")

pp! result
