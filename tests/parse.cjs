const fs = require('node:fs');
const path = require('node:path');
const parser = require(process.env.LUAPARSE_PATH || 'luaparse');
let count = 0;
function walk(dir) {
  for (const name of fs.readdirSync(dir)) {
    const file = path.join(dir, name);
    if (fs.statSync(file).isDirectory()) walk(file);
    else if (file.endsWith('.lua')) {
      parser.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''), {luaVersion: '5.1'});
      console.log('PARSE ' + file); count++;
    }
  }
}
walk('lua'); walk('tests');
console.log(count + ' Lua files passed Lua 5.1 syntax checks');
