// @ts-check
import './style.css'
import { Elm } from './Main.elm'
import { Listing, ListingDocument, OCRListingFile, Page } from './Types'
import * as pdfMake from 'pdfmake/build/pdfmake'
import * as pdfFonts from 'pdfmake/build/vfs_fonts'
import { PageSizes, PDFDocument, PDFEmbeddedPage, PDFFont, PDFImage, PDFPage, StandardFonts } from 'pdf-lib'
import { saveAs } from 'file-saver'

import { recogniseTextInTheseFiles } from './ocr'

// (<any>pdfMake).vfs = pdfFonts.pdfMake.vfs

//  Initialise
const app: any = Elm.Main.init({
  node: document.getElementById("app"),
})

//  Subscribe to ports
app.ports.getThePageCountOfThePDF.subscribe(getThePageCountOfThePDF)
app.ports.generateADocument.subscribe(generateADocument)
app.ports.ocrTheseDocuments.subscribe(ocrTheseDocuments)

async function getThePageCountOfThePDF(listing: Listing): Promise<void> {
  //  Find the number of pages
  try {
    let document = await PDFDocument.load(await listing.file.arrayBuffer())
    app.ports.gotPageCountOfPDF.send({ listingId: listing.id, pageCount: document.getPageCount() })
  } catch (error) {
    console.log('An error occurred when counting the number of pages in a PDF', error)
    app.ports.couldNotGetPageCountOfPDF.send(listing.id)
  }
}

async function generateADocument(e: { listings: Listing[], pages: Page[] }): Promise<void> {
  //  First, geenrate the index pages
  //  Next, generate all the content pages
  //  Combine the two
  //  Download it to the user
  let indexBlob: Blob = await generateTheIndexPages(e.listings)
  const index: PDFDocument = await PDFDocument.load(await indexBlob.arrayBuffer())
  const content: PDFDocument = await generateTheContentPages(e.listings)

  let indexPages: PDFPage[] = await content.copyPages(index, index.getPageIndices())
  indexPages.forEach((p, i) => {
    content.insertPage(i, p)
  })

  //  Done merging. Download the document.
  saveAs(new Blob([await content.save()]), 'indexAndDocuments.pdf')
}

async function generateTheIndexPages(listings: Listing[]): Promise<Blob> {
  let rows: [string, string, string][] = getListingsAsRows(listings)

  let docDefinition = {
    content: [
      {
        layout: 'lightHorizontalLines',
        table: {
          headerRows: 1,
          widths: ['auto', '*', 'auto'],
          body: [['Serial', 'Document', 'Page'], ...rows]
        }
      }
    ]
  }

  const pdfDocGenerator = pdfMake.createPdf(docDefinition, undefined, undefined, pdfFonts.pdfMake.vfs)
  return new Promise((resolve) => {
    pdfDocGenerator.getBlob((data: Blob) => {
      resolve(data)
    })
  })
}

function getListingsAsRows(listings: Listing[]): [string, string, string][] {
  let result: [string, string, string][] = []
  let pageNumber: number = 0
  listings.forEach((l: Listing, index: number) => {
    let row: [string, string, string] = [String(index + 1), l.title, String(pageNumber + 1)]
    result.push(row)
    pageNumber += l.numberOfPages
  })

  return result
}

async function generateTheContentPages(listings: Listing[]): Promise<PDFDocument> {

  //  Prepare the content pages

  //  First prepare a document for each listing
  let documents: PDFDocument[] =
    (await Promise.all(listings.map(getListingsFileAsADocument)))
      .sort((a, b) => { return a.index - b.index })
      .map((ld) => { return ld.document })

  //  Next, compile everything into one final document
  const finalDocument: PDFDocument = await PDFDocument.create()
  const finalDocumentFont: PDFFont = await finalDocument.embedFont(StandardFonts.Helvetica)

  //  Extract the documents from the listings and process each one's pages one at a time
  let pageNumber: number = 0
  for (const document of documents) {
    let pages = await finalDocument.copyPages(document, document.getPageIndices())
    for (const page of pages) {
      pageNumber++
      putInThePageNumber(pageNumber, finalDocumentFont, page)
      finalDocument.addPage(page)
    }
  }

  //  Return the document
  return finalDocument
}

async function getListingsFileAsADocument(listing: Listing): Promise<ListingDocument> {

  let document: PDFDocument = await PDFDocument.create()
  let pageSize: [number, number] = PageSizes.A4

  let fileType = listing.file.type
  if (fileType == 'application/pdf') {

    //  PDFs
    //  Go through each page of the PDF and return the embed
    let source: PDFDocument = await PDFDocument.load(await listing.file.arrayBuffer())
    let sourcePages: PDFPage[] = source.getPages()

    for (const sourcePage of sourcePages) {
      let e: PDFEmbeddedPage = await document.embedPage(sourcePage)
      let scaleFactor: number = Math.min(pageSize[0] / e.width, pageSize[1] / e.height)
      let scaledDimensions = { width: e.width * scaleFactor, height: e.height * scaleFactor }
      let newPage: PDFPage = document.addPage(pageSize)
      newPage.drawPage(e, {
        x: (pageSize[0] - scaledDimensions.width) / 2,
        y: (pageSize[1] - scaledDimensions.height) / 2,
        width: scaledDimensions.width,
        height: scaledDimensions.height
      })
    }

  } else if (fileType == 'image/png' || fileType == 'image/jpeg') {

    //  Images
    let e: PDFImage = (fileType == 'image/jpeg')
      ? await document.embedJpg(await listing.file.arrayBuffer())
      : await document.embedPng(await listing.file.arrayBuffer())
    let newPage: PDFPage = document.addPage(pageSize)
    let scaledDimensions = e.scaleToFit(pageSize[0], pageSize[1])
    newPage.drawImage(e, {
      x: (pageSize[0] - scaledDimensions.width) / 2,
      y: (pageSize[1] - scaledDimensions.height) / 2,
      width: scaledDimensions.width,
      height: scaledDimensions.height
    })

  }

  //  Done
  return { index: listing.index, document: document }
}

function putInThePageNumber(pageNumber: number, font: PDFFont, page: PDFPage) {
  const fontSizeOfPageNumber: number = 10

  const pageNumberAsString: string = String(pageNumber)
  const widthOfPageNumber: number = font.widthOfTextAtSize(pageNumberAsString, fontSizeOfPageNumber)
  const heightOfPageNumber: number = font.heightAtSize(fontSizeOfPageNumber)
  const rightMargin: number = 10

  page.moveTo(page.getWidth() - widthOfPageNumber - rightMargin, 1 * heightOfPageNumber)
  page.drawText(pageNumberAsString, { size: fontSizeOfPageNumber })
}



/****** OCR *********/
async function ocrTheseDocuments(ocrListingFiles: OCRListingFile[]): Promise<void> {
  console.log(ocrListingFiles)
  //  Now, differentiate between images and PDFs
  let results = await recogniseTextInTheseFiles(ocrListingFiles)
  //  Send the results to Elm
  console.log(results)
}