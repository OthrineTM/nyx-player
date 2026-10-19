import QtQuick

// Reads the most colorful tone of the album art from a tiny copy of it.
// It waits until the art has stopped changing for a moment, so covers flipping
// between several players don't start a pile of reads. Everything runs on the
// UI thread; Kirigami.ImageColors crashed plasmashell when reads overlapped.
Canvas {
    id: probe

    property string source: ""
    property color highlight: "#8a7fb0"
    property string loaded: ""

    width: 24
    height: 24
    opacity: 0
    enabled: false
    renderStrategy: Canvas.Immediate
    renderTarget: Canvas.Image

    onSourceChanged: settle.restart()

    Timer {
        id: settle
        interval: 1200
        onTriggered: {
            if (probe.loaded.length > 0 && probe.loaded !== probe.source) probe.unloadImage(probe.loaded)
            probe.loaded = probe.source
            if (probe.loaded.length === 0) return
            if (probe.isImageLoaded(probe.loaded)) probe.requestPaint()
            else probe.loadImage(probe.loaded)
        }
    }

    onImageLoaded: requestPaint()

    onPaint: {
        if (loaded.length === 0 || !isImageLoaded(loaded)) return
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.drawImage(loaded, 0, 0, width, height)
        var d = ctx.getImageData(0, 0, width, height).data
        var best = -1, pick = null
        for (var i = 0; i < d.length; i += 4) {
            if (d[i + 3] < 128) continue
            var c = Qt.rgba(d[i] / 255, d[i + 1] / 255, d[i + 2] / 255, 1)
            // colorful and neither near-black nor near-white
            var score = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.6)
            if (score > best) { best = score; pick = c }
        }
        if (pick) highlight = pick
    }
}
