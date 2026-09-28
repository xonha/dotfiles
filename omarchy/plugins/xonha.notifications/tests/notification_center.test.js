const test = require('node:test')
const assert = require('node:assert/strict')
const logic = require('../NotificationLogic.js')

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
