// @ts-check
import 'virtual:windi.css'
import './style.css'
import { Elm } from './Main.elm'
import * as pdfjsLib from 'pdfjs-dist'
import { Listing, ListingAndItsPages, ListingAndItsPagesAndTheirImages, Page, PageAndItsPDFPageProxy, PageAndItsImage, ListingAndItsPagesAndTheirPDFProxies } from './Types'
import { PDFPageProxy } from 'pdfjs-dist/types/src/display/api'
import docxload from 'docxload'

//  Initialise
const app: any = Elm.Main.init({
  node: document.getElementById("app"),
})
pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdn.jsdelivr.net/npm/pdfjs-dist@2.10.377/build/pdf.worker.js'

//  Subscribe to ports
app.ports.getThePageCountOfThePDF.subscribe(getThePageCountOfThePDF)
app.ports.getTheImagesDimensions.subscribe(getTheImagesDimensions)
app.ports.generateADocument.subscribe(generateADocument)

async function getThePageCountOfThePDF(listing: Listing): Promise<void> {
  //  Find the number of pages
  try {
    let document = await pdfjsLib.getDocument(await readFileAsDataURL(listing.file)).promise
    app.ports.gotPageCountOfPDF.send({ listingId: listing.id, pageCount: document.numPages })
  } catch (error) {
    console.log('An error occurred when counting the number of pages in a PDF', error)
    app.ports.couldNotGetPageCountOfPDF.send(listing.id)
  }
}

async function readFileAsDataURL(file: File): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    let reader = new FileReader()
    reader.addEventListener('loadend', (e): any => {
      if (e && e.target && e.target.result) {
        typeof e.target.result == 'string' ? resolve(e.target.result.toString()) : ''
      } else {
        reject('File couldn\'t be read.')
      }
    })
    reader.readAsDataURL(file)
  })
}

async function getTheImagesDimensions(listing: Listing): Promise<void> {
  //  Load the image up and get its dimensions
  let image = document.createElement('img')
  image.setAttribute('src', await readFileAsDataURL(listing.file) || "")
  image.onload = (): void => {
    //  Update the received page with the new details and send it back
    let page: Page = {
      id: 0,
      listingId: listing.id,
      naturalHeight: image.naturalHeight,
      naturalWidth: image.naturalWidth
    }

    app.ports.gotTheImagesDimensions.send(page)
  }
}


async function generateADocument(e: { template: string, listings: Listing[], pages: Page[] }) {
  // try {
  //  This is where we take the string sent here, and replace all the placeholders with the appropriate content
  console.log('Listings', e.listings)
  console.log('Pages', e.pages)
  let newTemplate: string = await generateTheseListingsPages(e)

  //  Get the pages' contents and put it into he Word document
  await docxload(newTemplate, { fileName: 'index.docx' })
  // }
  // catch (err) {
  //   console.log('An error occurred while producing the document', err)
  // }
}

async function generateTheseListingsPages(e: { template: string, listings: Listing[], pages: Page[] }): Promise<string> {
  let result: string = e.template

  let listingsAndTheirPages: ListingAndItsPages[] =
    e.listings.map((l: Listing): ListingAndItsPages => {
      return {
        listing: l,
        pages: getThisListingsPages(l.id, e.pages)
      }
    })

  let listingsAndTheirPagesAndTheirImages: ListingAndItsPagesAndTheirImages[] =
    await Promise.all(listingsAndTheirPages.map(async (listingAndItsPages: ListingAndItsPages): Promise<ListingAndItsPagesAndTheirImages> => {
      let result: ListingAndItsPagesAndTheirImages = {
        listing: listingAndItsPages.listing,
        pagesAndTheirImages: (listingAndItsPages.listing.file.type == 'application/pdf') ? await getThisListingsPagesAndTheirImages(listingAndItsPages) : [{ page: listingAndItsPages.pages[0], imageAsDataURL: await readFileAsDataURL(listingAndItsPages.listing.file) }]
      }

      return result
    }))

  //  Replace placeholders with their corresponding content
  listingsAndTheirPagesAndTheirImages.forEach((l: ListingAndItsPagesAndTheirImages) => {
    console.log(l)
    l.pagesAndTheirImages.forEach((p: PageAndItsImage): void => {
      let searchString: string = `data-listingId="${p.page.listingId}" data-pageId="${p.page.id}"`
      result = result.replace(searchString, `src="${p.imageAsDataURL}"`)
    })
  })

  //  Done
  return result
}

async function getThisListingsPagesAndTheirImages(l: ListingAndItsPages): Promise<PageAndItsImage[]> {
  //  There are two situations -- one is if the file is a PDF and one if it is not
  let result: PageAndItsImage[] = []
  // try {
  let pdf = await pdfjsLib.getDocument(await readFileAsDataURL(l.listing.file)).promise
  let pageNumbers: number[] = [...Array(pdf.numPages).keys()].map(x => x + 1)

  // let pagesAndTheirPDFPageProxies: PageAndItsPDFPageProxy[] =
  //   await Promise.all(pageNumbers.map(async (pageNumber: number) => {
  //     return {
  //       page: l.pages[pageNumber],
  //       pdfPageProxy: await pdf.getPage(pageNumber)
  //     }
  //   }))

  let pagesAndTheirImages: PageAndItsImage[] =
    await Promise.all(pageNumbers.map(async (pageNumber): Promise<PageAndItsImage> => {
      return {
        page: l.pages[pageNumber - 1],
        imageAsDataURL: await getAPageOfThePDFAsAnImage(await pdf.getPage(pageNumber))
      }
    }))

  result = pagesAndTheirImages
  // } catch (error) {
  //   console.log('An error occurred when getting a listings pages and their images', error)
  // }

  //  Done
  return result
}

function getThisListingsPages(listingId: number, pages: Page[]): Page[] {
  return pages.filter((p) => { return p.listingId == listingId })
}

async function getAPageOfThePDFAsAnImage(pageProxy: PDFPageProxy): Promise<string> {
  //  Render a page and send it back as an image
  let viewport = pageProxy.getViewport({ scale: 3 })
  let canvas = document.createElement('canvas')
  canvas.height = viewport.height
  canvas.width = viewport.width
  let context: any = canvas.getContext('2d', { alpha: false })
  let renderContext = { canvasContext: context, viewport: viewport }
  await pageProxy.render(renderContext).promise

  return canvas.toDataURL()
  // // return canvas.toDataURL() //  Defaults to PNG
  // return new Promise((resolve) => {
  //   let worker: Worker = new Worker('pdfRenderer.js')
  //   worker.postMessage(JSON.stringify(pageProxy))
  //   worker.onmessage = (e) => {
  //     resolve(e.data)
  //   }
  // })
}