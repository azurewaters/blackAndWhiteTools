// @ts-check

import { PDFPageProxy } from "pdfjs-dist/types/src/display/api"

interface Listing {
  id: number,
  file: File,
  index: number,
  title: string,
  numberOfPages: number,
  startingPageNumber: number,
  endingPageNumber: number
}

interface ListingAndItsPages {
  listing: Listing,
  pages: Page[]
}

interface ListingAndItsPagesAndTheirPDFProxies {
  listing: Listing,
  pagesAndTheirPDFProxies: PDFPageProxy[]
}

interface ListingAndItsPagesAndTheirImages {
  listing: Listing,
  pagesAndTheirImages: PageAndItsImage[]
}

interface Page {
  listingId?: number,
  id?: number,  //  Zero based id 
  naturalHeight?: number,
  naturalWidth?: number
}

interface PageAndItsPDFPageProxy {
  page: Page,
  pdfPageProxy: PDFPageProxy
}


interface PageAndItsImage {
  page: Page,
  imageAsDataURL: string //  Page's contents as a DataURL
}

export { Listing, ListingAndItsPages, ListingAndItsPagesAndTheirPDFProxies, ListingAndItsPagesAndTheirImages, Page, PageAndItsPDFPageProxy, PageAndItsImage }