// Parses every feature against the catalogue with the same bundled parser the
// server uses, and reports undefined or ambiguous steps. Usage:
//   node test/validate.cjs <catalogue.json> <feature>...
const fs = require('fs')
const path = require('path')
const registered = {}
globalThis.exports = (name, fn) => { registered[name] = fn }
require(path.resolve(__dirname, '../dist/parser.js'))

const catalogue = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
const definitions = JSON.stringify(catalogue.definitions)
const files = process.argv.slice(3)
let problems = 0, scenarios = 0, steps = 0
const used = new Set()
const report = (message) => { problems++; console.log('ERROR ' + message) }

for (const file of files) {
    const response = JSON.parse(registered.parseFeature(fs.readFileSync(file, 'utf8'), file, definitions, ''))
    if (!response.ok) { report(`${file}: ${response.error}`); continue }
    if (response.scenarios.length === 0) report(`${file}: no scenarios`)
    const names = new Map()
    for (const scenario of response.scenarios) {
        scenarios++
        if (!scenario.tags.includes('@kora') && file.includes('features/kora/')) report(`${file}:${scenario.location.line} "${scenario.name}" lacks the @kora tag`)
        // Outline rows share a name and a line; two separate scenarios must not.
        const seenAt = names.get(scenario.name)
        if (seenAt !== undefined && seenAt !== scenario.location.line) report(`${file}:${scenario.location.line} duplicate scenario name "${scenario.name}"`)
        names.set(scenario.name, scenario.location.line)
        for (const step of scenario.steps) {
            steps++
            if (step.error) report(`${file}:${step.location.line} ${step.error}: ${step.text}`)
            else used.add(step.definition)
        }
    }
}
// A kora feature that exists on disk but was never registered will not run.
const onDisk = files.filter((f) => f.includes('features/kora/')).map((f) => f.replace(/^\.\//, ''))
for (const file of onDisk) if (!catalogue.features.includes(file)) report(`${file}: no steps/kora file calls K.feature for it`)
const unused = catalogue.definitions.filter((d) => !d.hook && !used.has(d.id) && process.argv.includes('--unused'))
for (const d of unused) console.log('unused  ' + d.id)
console.log(`${files.length} features, ${scenarios} scenarios, ${steps} steps, ${catalogue.definitions.length} definitions, ${problems} problems`)
process.exit(problems ? 1 : 0)
