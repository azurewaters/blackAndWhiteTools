// @ts-check

import { PDFDocument } from "pdf-lib"

interface Listing {
  id: number,
  file: File,
  index: number,
  title: string,
  numberOfPages: number,
  startingPageNumber: number,
  endingPageNumber: number
}

interface Page {
  listingId?: number,
  id?: number,  //  Zero based id 
  naturalHeight?: number,
  naturalWidth?: number
}

interface ListingDocument {
  index: number,
  document: PDFDocument
}

export { Listing, Page, ListingDocument }