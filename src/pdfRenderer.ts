import { PDFPageProxy } from 'pdfjs-dist/types/src/display/api'

onmessage = async (e: MessageEvent) => {
  //  Render a page and send it back as an image
  let pageProxy: PDFPageProxy = JSON.parse(e.data)
  console.log(pageProxy)
  let viewport = pageProxy.getViewport({ scale: 2 })
  let canvas = document.createElement('canvas')
  canvas.height = viewport.height
  canvas.width = viewport.width

  let context: any = canvas.getContext('2d', { alpha: false })
  let renderContext = { canvasContext: context, viewport: viewport }
  await pageProxy.render(renderContext).promise

  postMessage(canvas.toDataURL())
}