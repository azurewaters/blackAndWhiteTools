// @ts-check
import 'virtual:windi.css'
import './style.css'
import { Elm } from './Main.elm'
import * as pdfjsLib from 'pdfjs-dist'
import { Listing, Page } from './Types'
import { PDFPageProxy } from 'pdfjs-dist/types/src/display/api'
import docxload from 'docxload'

//  Initialise
const app: any = Elm.Main.init({
  node: document.getElementById("app"),
})
pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdn.jsdelivr.net/npm/pdfjs-dist@2.10.377/build/pdf.worker.js'

//  Subscribe to ports
app.ports.getPageCountOfPDF.subscribe(getPageCountOfPDF)
app.ports.getPagesOfPDFAsASetOfImages.subscribe(getPagesOfPDFAsASetOfImages)
app.ports.generateADocument.subscribe(generateADocument)
app.ports.getTheImagesDimensions.subscribe(getTheImagesDimensions)

async function getPageCountOfPDF(e: { listingId: number, url: string }): Promise<void> {
  //  Find the number of pages
  try {
    let document = await pdfjsLib.getDocument(e.url).promise
    app.ports.gotPageCountOfPDF.send({ listingId: e.listingId, pageCount: document.numPages })
  } catch (error) {
    console.log('An error occurred when counting the number of pages in a PDF', error)
    app.ports.couldNotGetPageCountOfPDF.send(e.listingId)
  }
}

async function getTheImagesDimensions(page: Page): Promise<void> {
  //  Load the image up and get its dimensions
  let image = document.createElement('img')
  image.setAttribute('src', page.contents || "")
  image.onload = (): void => {
    //  Update the received page with the new details and send it back
    page.naturalHeight = image.naturalHeight
    page.naturalWidth = image.naturalWidth
    app.ports.gotPagesOfListing.send([page])
  }
}

async function getThePageAsAnImage(page: PDFPageProxy): Promise<Page> {
  //  Render a page and send it back as an image
  let viewport = page.getViewport({ scale: 1 })
  let canvas = document.createElement('canvas')
  canvas.height = viewport.height
  canvas.width = viewport.width
  let context: any = canvas.getContext('2d')
  let renderContext = { canvasContext: context, viewport: viewport }
  await page.render(renderContext).promise

  let result: Page = {
    contents: canvas.toDataURL(),
    naturalHeight: canvas.height,
    naturalWidth: canvas.width
  }

  return result
}

async function generateADocument(template: string) {
  console.log('Came to generateADocument')
  //  This is where we take the string sent here, and generate a docx using docxLoad
  try {
    await docxload(template, { fileName: 'index.docx' })
  }
  catch (err) {
    console.log('An error occurred while producing the document', err)
  }
}

async function getPagesOfPDFAsASetOfImages(listing: Listing): Promise<void> {
  //  Now, check to see if the listing's file is a PDF
  //  If it is, load up the PDF document
  //  Get the list of pages in the PDF
  //  Send that off to the function that will render the page as an image and return its dataURL
  if (listing.fileContents) {
    let result: Array<Page> = []
    try {
      let pdf = await pdfjsLib.getDocument(listing.fileContents).promise
      let pageNumbers: Array<number> = [...Array(pdf.numPages).keys()].map(x => x + 1)
      let pdfPages: Array<PDFPageProxy> = await Promise.all(pageNumbers.map((pageNumber) => { return pdf.getPage(pageNumber) }))
      let pdfPagesAsPages: Array<Page> = await Promise.all(pdfPages.map((p: PDFPageProxy) => { return getThePageAsAnImage(p) }))

      //  Insert the data that the Page objects don't already have
      result =
        pdfPagesAsPages.map((p: Page, i: number) => {
          p.listingId = listing.id
          p.id = i  //  Zero based id

          return p
        })

      //  Done. Let Elm know.
      app.ports.gotPagesOfListing.send(result)
    } catch (error) {
      //  An error occurred. Let Elm know.
      console.log('Error while extracting the pages as images', error)
      app.ports.couldNotGetPagesOfListing.send(listing.id)
    }
  } else {
    //  An error occurred. Let Elm know.
    app.ports.couldNotGetPagesOfListing.send(listing.id)
  }
}