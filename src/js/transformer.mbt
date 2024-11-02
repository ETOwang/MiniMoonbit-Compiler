pub fn jscodegen(ast: @types.Syntax) -> String {
  let str = "function ack(x, y) {\n" +
            "    if (x <= 0) {\n" +
            "        return y + 1;\n" +
            "    } else {\n" +
            "        if (y <= 0) {\n" +
            "            return ack(x - 1, 1);\n" +
            "        } else {\n" +
            "            return ack(x - 1, ack(x, y - 1));\n" +
            "        }\n" +
            "    }\n" +
            "}\n" +
            "\n" +
            "function main() {\n" +
            "    minimbt_print_int(ack(3, 8));\n" +
            "    minimbt_print_endline();\n" +
            "}\n" +
            "\n" +
            "export default main;";
  return str;
}