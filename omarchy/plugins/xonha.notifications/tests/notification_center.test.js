const test = require('node:test')
const assert = require('node:assert/strict')
const logic = require('../NotificationLogic.js')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { execFileSync } = require('node:child_process')

function withArchive(run) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'notification-center-delete-'))
  const history = path.join(dir, 'saved history')
  const images = path.join(dir, 'saved images')
  fs.mkdirSync(history)
  fs.mkdirSync(images)
  try { run({ dir, history, images }) } finally { fs.rmSync(dir, { recursive: true, force: true }) }
}

function execute(command) { execFileSync(command[0], command.slice(1)) }

test('positions choose one vertical and one horizontal anchor', () => {
  for (const vertical of ['top', 'bottom']) {
    for (const horizontal of ['left', 'center', 'right']) {
      const { anchors } = logic.popupPlacement('top', 38, 8, `${vertical}-${horizontal}`)
      assert.equal(anchors.top, vertical === 'top')
      assert.equal(anchors.bottom, vertical === 'bottom')
      assert.equal(anchors.left, horizontal === 'left')
      assert.equal(anchors.right, horizontal === 'right')
      assert.equal(anchors.horizontalCenter, horizontal === 'center')
    }
  }
})

test('toasts clear bars on each edge', () => {
  for (const edge of ['top', 'bottom', 'left', 'right']) {
    const { margins } = logic.popupPlacement(edge, 38, 8, 'bottom-right')
    for (const side of ['top', 'bottom', 'left', 'right'])
      assert.equal(margins[side], side === edge ? 38 : 8)
  }
  assert.equal(logic.normalizePosition('invalid'), 'top-center')
  assert.equal(logic.normalizePosition(null), 'top-center')
})

test('persistent history uses the selected limit and keeps newest entries', () => {
  const entries = Array.from({ length: 120 }, (_, id) => ({ id: id + 1, originalId: id + 1, timestamp: 1000 + id, summary: `test ${id}` }))
  const raw = entries.map(entry => JSON.stringify(entry)).join('\n')
  const history = logic.historyRows(raw, [entries[119]], 1, 100)
  assert.equal(history.length, 100)
  assert.equal(history[0].summary, 'test 119')
  assert.equal(history[99].summary, 'test 20')
  assert.equal(logic.historyRows(raw, [], 1, 25).length, 25)
})

test('individual removal deletes only its record and images, including similar ids', () => {
  withArchive(({ history, images }) => {
    for (const name of ['1000-1.json', '1000-10.json']) fs.writeFileSync(path.join(history, name), '{}')
    for (const name of ['1000-1-avatar', '1000-1-image', '1000-10-avatar', '1001-1-avatar'])
      fs.writeFileSync(path.join(images, name), 'image')
    execute(logic.historyRemovalCommand({ timestamp: 1000, originalId: 1 }, history, images))
    assert.deepEqual(fs.readdirSync(history), ['1000-10.json'])
    assert.deepEqual(fs.readdirSync(images), ['1000-10-avatar', '1001-1-avatar'])
  })
})

test('individual removal rejects malformed identities and traversal', () => {
  for (const entry of [null, {}, { timestamp: '../other', originalId: 1 },
    { timestamp: 1000, originalId: '../../other' }, { timestamp: Infinity, originalId: 1 },
    { timestamp: 1000.5, originalId: 1 }, { timestamp: 1000, originalId: -1 },
    { timestamp: 0, originalId: 1 }])
    assert.equal(logic.historyRemovalCommand(entry, '/unused/history', '/unused/images'), null)
})

test('clear history removes archived images while preserving live popups and unrelated files', () => {
  withArchive(({ dir, history, images }) => {
    const popup = path.join(dir, '2000-1.json')
    fs.writeFileSync(popup, '{}')
    fs.writeFileSync(path.join(images, '2000-1-avatar'), 'live image')
    fs.writeFileSync(path.join(history, 'notes.txt'), 'keep')
    for (const stem of ['1000-1', '1000-2', "odd ' $(name)"]) {
      fs.writeFileSync(path.join(history, stem + '.json'), '{}')
      fs.writeFileSync(path.join(images, stem + '-avatar'), 'image')
    }
    execute(logic.clearHistoryCommand(history, images))
    assert.deepEqual(fs.readdirSync(history), ['notes.txt'])
    assert.deepEqual(fs.readdirSync(images), ['2000-1-avatar'])
    assert.equal(fs.existsSync(popup), true)
    // Clearing an already empty history is safe.
    execute(logic.clearHistoryCommand(history, images))
    assert.equal(fs.existsSync(popup), true)
  })
})
