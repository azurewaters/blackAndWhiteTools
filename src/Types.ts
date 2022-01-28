// @ts-check

import { PDFDocument } from "pdf-lib"
import Tesseract from "tesseract.js"

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

interface OCRListingFile {
  ocrListingId: number,
  file: File
}

interface OCRRecognitionResult {
  ocrListingId: number,
  text: string
}

export { Listing, Page, ListingDocument, OCRListingFile, OCRRecognitionResult }