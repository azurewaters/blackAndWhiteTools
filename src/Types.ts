// @ts-check

interface Listing {
  id: number,
  fileContents: string,
  index: number,
  title: string,
  numberOfPages: number,
  startingPageNumber: number,
  endingPageNumber: number
}

interface Page {
  listingId?: number,
  id?: number,
  contents?: string,
  naturalHeight?: number,
  naturalWidth?: number
}

export { Listing, Page }