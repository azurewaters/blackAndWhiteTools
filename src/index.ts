// @ts-check
import './style.css'
import { Elm } from './Main.elm'
import * as pdfjsLib from 'pdfjs-dist'
// import { convertMillimetersToTwip, Document, ISectionOptions, NumberFormat, Packer, PageNumber, PageOrientation, Paragraph, Table, TableCell, TableRow, TextRun, WidthType, Header, ImageRun, PageSize, convertInchesToTwip, AlignmentType } from 'docx'
import { Listing, Page } from './Types'
// import { saveAs } from 'file-saver'
import { PDFDocumentProxy, PDFPageProxy } from 'pdfjs-dist/types/src/display/api'
import docxload from 'docxload'

//  Initialise
const app: any = Elm.Main.init({
  node: document.getElementById("app"),
})
pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdn.jsdelivr.net/npm/pdfjs-dist@2.10.377/build/pdf.worker.js'

const PAPER_SIZE = { height: 297, width: 210 }

//  Subscribe to ports
app.ports.getPageCountOfPDF.subscribe(getPageCountOfPDF)
// app.ports.produceDocument.subscribe(produceDocument)
app.ports.getPagesOfPDFAsASetOfImages.subscribe(getPagesOfPDFAsASetOfImages)
app.ports.generateADocument.subscribe(generateADocument)

async function getPageCountOfPDF(e: any): Promise<void> {
  //  Find the number of pages
  try {
    let document = await pdfjsLib.getDocument(e.url).promise
    app.ports.gotPageCountOfPDF.send({ listingId: e.listingId, pageCount: document.numPages })
  } catch (error) {
    console.log('An error occurred when counting the number of pages in a PDF', error)
    app.ports.couldNotGetPageCountOfPDF.send(e.listingId)
  }
}

// async function produceDocument(e: Array<ListingWithPageNumbers>): Promise<void> {
//   //  This is where we take the listings and produce a Word Document
//   //  Logic: Go through each of the listings and produce a table row for each
//   //  Put the tablerows into a table
//   //  Put the table into a section
//   //  Put the section into a document
//   //  Download
//   let listings: Array<ListingWithPageNumbers> = e

//   let index: ISectionOptions = makeAnIndex(listings)
//   let innerPages: ISectionOptions = await makeTheInnerPages(listings)

//   let document: Document = new Document({
//     background: {
//       color: "ffffff"
//     },
//     sections: [index, innerPages]
//   })

//   let blob = await Packer.toBlob(document)
//   saveAs(blob, "index.docx")
// }

// function makeAnIndex(listings: Array<ListingWithPageNumbers>): ISectionOptions {

//   //  Make the header
//   let pageNumberHeader: Header = new Header({
//     children: [
//       new Paragraph({ children: [new TextRun({ children: [PageNumber.CURRENT] })] })
//     ]
//   })

//   //  Make the table header
//   let tableHeader: Array<TableRow> = [
//     new TableRow({
//       tableHeader: true,
//       children: [
//         new TableCell({ children: [new Paragraph({ children: [new TextRun({ bold: true, text: 'Serial' })] })] })
//         , new TableCell({ children: [new Paragraph({ children: [new TextRun({ bold: true, text: 'Description' })] })] })
//         , new TableCell({ children: [new Paragraph({ children: [new TextRun({ bold: true, text: 'Page(s)' })] })] })
//       ]
//     })
//   ]

//   //  Make the table
//   let table: Table = new Table({
//     width: {
//       size: 100,
//       type: WidthType.PERCENTAGE
//     },
//     rows: tableHeader.concat(listings.map<TableRow>(makeARow))
//   })

//   let result: any = {
//     properties: {
//       page: {
//         pageNumbers: {
//           start: 1,
//           formatType: NumberFormat.LOWER_ROMAN,
//         },
//         size: {
//           orientation: PageOrientation.PORTRAIT,
//           height: convertMillimetersToTwip(PAPER_SIZE.height),
//           width: convertMillimetersToTwip(PAPER_SIZE.width),
//         },
//       },
//     },
//     headers: { default: pageNumberHeader },
//     children: [table]
//   }

//   return result
// }

// function makeARow(listing: ListingWithPageNumbers): TableRow {
//   //  Calculate the page range
//   let pageRange: string = ""
//   if (listing.startingPageNumber == listing.endingPageNumber) {
//     pageRange = String(listing.startingPageNumber)
//   } else {
//     pageRange = String(listing.startingPageNumber) + " - " + String(listing.endingPageNumber)
//   }

//   //  Produce the TableRow
//   return new TableRow({
//     children: [
//       new TableCell({ children: [new Paragraph(String(listing.index))] })
//       , new TableCell({ children: [new Paragraph(listing.title)] })
//       , new TableCell({ children: [new Paragraph(pageRange)] })
//     ]
//   })
// }

// async function makeTheInnerPages(listings: Array<ListingWithPageNumbers>): Promise<ISectionOptions> {

//   //  Take each listing and get its pages as an image
//   //  Take each image and put it into a paragraph
//   //  Put these paragraphs into a section
//   //  Return result

//   let pagesAsImages: Array<string> = (await Promise.all(listings.map(getTheListingsPagesAsImages))).flat()
//   let imagesAsParagraphs: Array<Paragraph> = await Promise.all(pagesAsImages.map(imageInAParagraph))

//   //  Put the whole thing into a section
//   //  Make the header for the section
//   let pageNumberHeader: Header = new Header({
//     children: [
//       new Paragraph({ children: [new TextRun({ children: [PageNumber.CURRENT] })], alignment: AlignmentType.RIGHT })
//     ]
//   })

//   let sectionContainingParagraphs: ISectionOptions = {
//     properties: {
//       page: {
//         margin: { top: convertInchesToTwip(1), right: convertInchesToTwip(1), bottom: convertInchesToTwip(1), left: convertInchesToTwip(1) }, //  Default margins in Word
//         pageNumbers: {
//           start: 1,
//           formatType: NumberFormat.DECIMAL,
//         },
//         size: {
//           orientation: PageOrientation.PORTRAIT,
//           height: convertMillimetersToTwip(PAPER_SIZE.height),
//           width: convertMillimetersToTwip(PAPER_SIZE.width),
//         },
//       },
//     },
//     headers: { default: pageNumberHeader },
//     children: imagesAsParagraphs
//   }

//   return sectionContainingParagraphs
// }

// async function getTheListingsPagesAsImages(l: ListingWithPageNumbers): Promise<Array<string>> {
//   //  If it is a simple image, then just send the image back
//   //  If it is a PDF, load up the PDF, extract each page as an image, and send an array back
//   let result: Array<string> = []
//   if (l.fileMIMEType == 'application/pdf') {
//     try {
//       let document = await pdfjsLib.getDocument(l.fileContents).promise
//       let pageNumbers: Array<number> = [...Array(document.numPages).keys()].map(x => x + 1)
//       let pdfPages: Array<PDFPageProxy> = await Promise.all(pageNumbers.map((pageNumber: number) => { return document.getPage(pageNumber) }))
//       result = await Promise.all(pdfPages.map((p: PDFPageProxy) => { return getThePageAsAnImage(p) }))
//     } catch (error) {
//       console.log('Error while extracting the pages', error)
//     }
//   } else {
//     //  It is already an image
//     result = [l.fileContents]
//   }

//   console.log("getTheListingsPagesAsImages", result)
//   return result
// }

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

// async function imageInAParagraph(i: string): Promise<Paragraph> {
//   let im = document.createElement('img')
//   im.src = i
//   let originalDimensions: { height: number, width: number } = await new Promise((resolve, reject) => {
//     im.onload = (e) => {
//       console.log('image loaded')
//       resolve({ height: im.naturalHeight, width: im.width })
//     }
//   })

//   //  Now, size things down
//   let maxWidth: number = Math.floor(PAPER_SIZE.width - convertInchesToTwip(2)),
//     maxHeight: number = Math.floor(PAPER_SIZE.height - convertInchesToTwip(2))

//   let finalDimensions: { height: number, width: number } = { height: originalDimensions.height, width: originalDimensions.width }
//   if (originalDimensions.width > PAPER_SIZE.width || originalDimensions.height > PAPER_SIZE.height) {
//     let hRatio = maxWidth / originalDimensions.width
//     let vRatio = maxHeight / originalDimensions.height
//     let ratio = Math.min(hRatio, vRatio)
//     finalDimensions.height = Math.floor(originalDimensions.height * ratio)
//     finalDimensions.width = Math.floor(originalDimensions.width * ratio)
//   }

//   //  
//   let result: Paragraph = new Paragraph({
//     children: [
//       new ImageRun({
//         data: i,
//         transformation: {
//           height: finalDimensions.height,
//           width: finalDimensions.width
//         },
//       })
//     ], pageBreakBefore: true
//   })

//   return result
// }

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
      app.ports.gotPagesOfPDFAsASetOfImages.send(result)
    } catch (error) {
      //  An error occurred. Let Elm know.
      console.log('Error while extracting the pages as images', error)
      app.ports.couldNotGetPagesOfPDFAsASetOfImages.send(listing.id)
    }
  } else {
    //  An error occurred. Let Elm know.
    app.ports.couldNotGetPagesOfPDFAsASetOfImages.send(listing.id)
  }
}

