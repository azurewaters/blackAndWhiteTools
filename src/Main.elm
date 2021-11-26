port module Main exposing (main)

import Browser
import File exposing (File)
import Html exposing (Attribute, Html, a, button, div, text)
import Html.Attributes exposing (class, classList, disabled, draggable, id, style)
import Html.Events exposing (on, onClick, preventDefaultOn)
import Html.Keyed as Keyed
import Json.Decode as Decode exposing (Decoder, Error(..))
import Json.Encode as Encode
import Svg.Attributes exposing (visibility)
import Task



-- MODEL


type CurrentScreen
    = Home
    | IndexMaker


type alias Id =
    Int


type alias Index =
    Int


type PageCount
    = Counting
    | Counted Int
    | Unvailable --  An error of some sort occurred


type alias Page =
    { listingId : Id
    , id : Id
    , contents : DataURL --  The page's image as a dataURL
    , naturalHeight : Int
    , naturalWidth : Int
    }


type alias Pages =
    List Page


type PagesContentsRetrievalStatus
    = Standby
    | Processing
    | Retrieved
    | Error


type alias NumberOfPagesInListing =
    { listingId : Int
    , pageCount : Int
    }


type alias DataURL =
    String


type alias Listing =
    { id : Id
    , file : File
    , fileContents : DataURL --  The file's contents as a dataURL
    , index : Index
    , title : String
    , numberOfPages : PageCount
    , startingPageNumber : Int
    , endingPageNumber : Int
    , pagesContentsRetrievalStatus : PagesContentsRetrievalStatus
    }


type alias Model =
    { currentScreen : CurrentScreen
    , listings : List Listing
    , pages : Pages
    , lastListingsId : Int --  lastListingsId used in calculating page numbers
    , listingBeingDragged : Maybe Listing
    , enableDownloadButton : Bool
    }


type alias Flags =
    {}


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { currentScreen = IndexMaker
      , listings = []
      , pages = []
      , lastListingsId = 0
      , listingBeingDragged = Nothing
      , enableDownloadButton = False
      }
    , Cmd.none
    )



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Black and White Tools"
    , body = [ viewRoot model ]
    }


viewRoot : Model -> Html Msg
viewRoot model =
    div
        [ class "h-screen w-full bg-black grid grid-cols-1 content-start text-white space-y-8 p-8"
        , style "grid-template-rows" "min-content 1fr min-content"
        ]
        [ pageHeader model.currentScreen
        , div
            [ class "h-full overflow-y-auto" ]
            [ case model.currentScreen of
                Home ->
                    home

                IndexMaker ->
                    indexMaker model
            ]
        , pageFooter
        ]


pageHeader : CurrentScreen -> Html Msg
pageHeader currentPage =
    div [ class "grid grid-flow-col w-full gap-8 w-max" ]
        [ div [ class "font-bold text-green-500" ] [ text "Black and White Tools" ]
        , div [ class "grid grid-flow-col gap-4 w-max" ]
            [ navigationLink HomeLinkClicked (currentPage == Home) "Home"
            , navigationLink IndexMakerLinkClicked (currentPage == IndexMaker) "Index Maker"
            ]
        ]


navigationLink : Msg -> Bool -> String -> Html Msg
navigationLink msg show linkText =
    a
        [ onClick msg
        , class "cursor-pointer"
        , classList [ ( "font-semibold", show ), ( "text-green-500", show ) ]
        ]
        [ text linkText ]


pageFooter : Html Msg
pageFooter =
    div [ class "w-full flex justify-center text-xs text-gray-500 pt-4 pb-4" ]
        [ text "© 2021 azurewaters.in"
        ]


home : Html Msg
home =
    div [] [ text "Home" ]


indexMaker : Model -> Html Msg
indexMaker model =
    let
        disableTheDownloadButton : Bool
        disableTheDownloadButton =
            List.length model.listings == 0
    in
    div
        [ class "min-h-full max-h-full grid grid-flow-row gap-4"
        , style "grid-template-rows" "min-content 1fr min-content"
        ]
        [ div
            [ class "grid grid-flow-col content-start gap-4"
            , style "grid-template-columns" "1fr auto"
            ]
            [ dropZone
            , button
                [ onClick ClearAllButtonClicked
                , class "py-2 px-4 text-lg border-2 border-transparent hover:border-green-500 disabled:hover:border-gray-500 rounded-md disabled:bg-grey-500 text-gray-900 font-semibold"
                , class "bg-green-600 hover:bg-green-500 disabled:bg-gray-400"
                , disabled disableTheDownloadButton
                ]
                [ text "Clear all" ]
            ]
        , Keyed.node "div"
            [ class "h-full overflow-y-auto grid content-start sm:grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 w-full" ]
            (List.map (\l -> ( l.id |> String.fromInt, listItem l )) model.listings)
        , div
            [ class "grid grid-flow-col justify-center mt-4" ]
            [ button
                [ onClick DownloadDocumentButtonClicked
                , class "px-4 py-2 text-lg border-2 border-transparent hover:border-green-500 disabled:hover:border-gray-500 rounded-md disabled:bg-grey-500 text-gray-900 font-semibold"
                , class "bg-green-600 hover:bg-green-500 disabled:bg-gray-400"
                , model.enableDownloadButton |> not |> disabled
                ]
                [ text "Download" ]
            ]
        ]


dropZone : Html Msg
dropZone =
    div
        [ onFilesDrop FilesDropped
        , onDragOver NoOp
        , class "h-12 w-full bg-gray-900 rounded-md grid justify-center content-center text-sm text hover:bg-gray-800"
        ]
        [ div [ class "text-gray-500", disabled True ] [ text "Drop your documents here (*.pdf, *.jpg, *.png)" ]
        ]


onDragStart : Msg -> Attribute Msg
onDragStart msg =
    on "dragstart" (Decode.succeed msg)


onDragOver : Msg -> Attribute Msg
onDragOver msg =
    preventDefaultOn "dragover" (Decode.succeed ( msg, True ))


onDrop : Msg -> Attribute Msg
onDrop msg =
    preventDefaultOn "drop" (Decode.succeed ( msg, True ))


onFilesDrop : (List File -> Msg) -> Attribute Msg
onFilesDrop msg =
    preventDefaultOn "drop" (Decode.map2 Tuple.pair (Decode.map msg filesDecoder) (Decode.succeed True))


filesDecoder : Decoder (List File)
filesDecoder =
    Decode.at [ "dataTransfer", "files" ] (Decode.list File.decoder)


onDragEnd : Msg -> Attribute Msg
onDragEnd msg =
    on "dragend" (Decode.succeed msg)


listItem : Listing -> Html Msg
listItem listing =
    div
        [ onDragStart (ListingDragStart listing)
        , onDragOver NoOp
        , onDrop (ListingDrop listing)
        , onDragEnd ListingDragEnd
        , class "group grid text-sm p-4 gap-4 rounded-md border-2 border-transparent hover:border-green-500 max-w-md bg-gray-900 p-2"
        , style "grid-template-columns" "minmax(10px, min-content) 1fr minmax(10px, min-content)"
        , draggable "true"
        ]
        [ listing.index |> String.fromInt |> text
        , div
            [ class "max-h-full w-full grid gap-2"
            , style "grid-template-rows" "1fr 10px"
            ]
            [ div [ class "overflow-auto max-w-full max-h-6" ] [ listing.title |> text ]
            , div [ class "text-xs text-gray-500" ]
                [ text
                    (case listing.numberOfPages of
                        Counting ->
                            "Counting pages"

                        Counted 1 ->
                            "1 page"

                        Counted x ->
                            String.fromInt x ++ " pages"

                        Unvailable ->
                            "Page count unavailable"
                    )
                ]
            ]
        , button
            [ onClick (ListItemsDeleteButtonClicked listing.id)
            , class "items-center hidden group-hover:grid transform rotate-45"
            ]
            [ text "+" ]
        ]



-- UPDATE


type Msg
    = NoOp
    | HomeLinkClicked
    | IndexMakerLinkClicked
    | FilesDropped (List File)
    | ListItemsDeleteButtonClicked Id
    | ListingDragStart Listing
    | ListingDrop Listing
    | ListingDragEnd
    | ConvertedFileToURL Listing String
    | GotNumberOfPagesInListing NumberOfPagesInListing
    | CouldNotGetNumberOfPagesInListing Id
    | ClearAllButtonClicked
    | DownloadDocumentButtonClicked
    | GotPagesOfListing Pages
    | CouldNotGetPagesOfListing Id


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        HomeLinkClicked ->
            ( { model | currentScreen = Home }, Cmd.none )

        IndexMakerLinkClicked ->
            ( { model | currentScreen = IndexMaker }, Cmd.none )

        FilesDropped files ->
            let
                admissibleFiles : List File
                admissibleFiles =
                    List.filter
                        (\f -> List.member (File.mime f) [ "application/pdf", "image/jpeg", "image/png", "image/tiff" ])
                        files

                maxIndex : Int
                maxIndex =
                    List.map .index model.listings
                        |> List.maximum
                        |> Maybe.withDefault 0

                newIds : List Int
                newIds =
                    List.range (model.lastListingsId + 1) (model.lastListingsId + List.length admissibleFiles)

                newIndexes : List Int
                newIndexes =
                    List.range
                        (maxIndex + 1)
                        (maxIndex + List.length admissibleFiles)

                newListings : List Listing
                newListings =
                    List.map3
                        (\file id index ->
                            { id = id
                            , file = file
                            , fileContents = ""
                            , index = index
                            , title = file |> File.name |> removeFileExtension
                            , numberOfPages = Counting
                            , startingPageNumber = 0
                            , endingPageNumber = 0
                            , pagesContentsRetrievalStatus = Standby
                            }
                        )
                        admissibleFiles
                        newIds
                        newIndexes

                newCommands : List (Cmd Msg)
                newCommands =
                    List.map
                        (\l ->
                            Task.perform (ConvertedFileToURL l) (File.toUrl l.file)
                        )
                        newListings
            in
            ( { model
                | listings = List.append model.listings newListings
                , lastListingsId = model.lastListingsId + List.length newListings
              }
            , Cmd.batch newCommands
            )

        ListItemsDeleteButtonClicked id ->
            let
                newListings : List Listing
                newListings =
                    List.filter (\l -> l.id == id |> not) model.listings

                newPages : Pages
                newPages =
                    List.filter (\p -> p.listingId /= id) model.pages
            in
            ( { model | listings = reIndexListings newListings, pages = newPages }, Cmd.none )

        ListingDragStart listing ->
            ( { model | listingBeingDragged = Just listing }, Cmd.none )

        ListingDrop listingDroppedOn ->
            let
                listingBeingDragged : Listing
                listingBeingDragged =
                    case model.listingBeingDragged of
                        Just l ->
                            l

                        Nothing ->
                            --  It should never come here
                            listingDroppedOn

                newListings : List Listing
                newListings =
                    List.filter (\l -> l.id /= listingBeingDragged.id) model.listings
                        |> List.map
                            (\l ->
                                if l.index < listingDroppedOn.index then
                                    l

                                else
                                    { l | index = l.index + 1 }
                            )
                        |> (::) { listingBeingDragged | index = listingDroppedOn.index }
                        |> List.sortBy .index
                        |> reIndexListings
            in
            ( { model | listings = newListings }, Cmd.none )

        ListingDragEnd ->
            ( { model | listingBeingDragged = Nothing }, Cmd.none )

        ConvertedFileToURL listing url ->
            let
                isAPDF : Bool
                isAPDF =
                    File.mime listing.file == "application/pdf"

                updatedListings : List Listing
                updatedListings =
                    List.map
                        (\l ->
                            if l.id == listing.id then
                                { l
                                    | fileContents = url
                                    , numberOfPages =
                                        if isAPDF then
                                            Counting

                                        else
                                            Counted 1
                                }

                            else
                                l
                        )
                        model.listings

                newCommand : Cmd msg
                newCommand =
                    if isAPDF then
                        getPageCountOfPDF (encodeDetailsForPageCount listing.id url)

                    else
                        getTheImagesDimensions (Page listing.id 0 url 0 0)
            in
            ( { model | listings = updatedListings }, newCommand )

        GotNumberOfPagesInListing numberOfPagesInListing ->
            let
                theListing : Maybe Listing
                theListing =
                    List.filter (\l -> l.id == numberOfPagesInListing.listingId) model.listings
                        |> List.head

                updatedListings : List Listing
                updatedListings =
                    List.map
                        (\l ->
                            if l.id == numberOfPagesInListing.listingId then
                                { l
                                    | numberOfPages = Counted numberOfPagesInListing.pageCount
                                    , pagesContentsRetrievalStatus = Processing
                                }

                            else
                                l
                        )
                        model.listings

                newCommand : Cmd Msg
                newCommand =
                    case theListing of
                        Just l ->
                            encodeListingForPagesContentsExtraction l |> getPagesOfPDFAsASetOfImages

                        Nothing ->
                            Cmd.none
            in
            ( { model
                | listings = updatedListings
                , enableDownloadButton = listingsStillBeingProcessed updatedListings |> not
              }
            , newCommand
            )

        CouldNotGetNumberOfPagesInListing listingId ->
            let
                updatedListings : List Listing
                updatedListings =
                    List.map
                        (\l ->
                            if l.id == listingId then
                                { l | numberOfPages = Unvailable }

                            else
                                l
                        )
                        model.listings
            in
            ( { model
                | listings = updatedListings
                , enableDownloadButton = listingsStillBeingProcessed updatedListings |> not
              }
            , Cmd.none
            )

        ClearAllButtonClicked ->
            ( { model | listings = [], pages = [] }, Cmd.none )

        DownloadDocumentButtonClicked ->
            let
                {--
                    This button is clickable only when each listing's pages have been counted and a PDF's pages have been processed.
                    Step 1: Make the index
                        Arrange the listings by index number
                        Calculate each listing's page numbers
                        Output the index, title and page numbers into a table row each, and then wrap that into a table
                        Put that table into a page
                    Step 2: Make the individual pages
                        Wrap each image in each listing with a page tag
                --}
                index : String
                index =
                    makeAnIndex model.listings

                pages : String
                pages =
                    makeTheInnerPages model.listings model.pages
            in
            ( model, Encode.string (index ++ pages) |> generateADocument )

        GotPagesOfListing pages ->
            let
                listingId : Int
                listingId =
                    case pages of
                        head :: _ ->
                            head.listingId

                        _ ->
                            -1

                updatedListings : List Listing
                updatedListings =
                    List.map
                        (\l ->
                            if l.id == listingId then
                                { l | pagesContentsRetrievalStatus = Retrieved }

                            else
                                l
                        )
                        model.listings

                newPagesContents : Pages
                newPagesContents =
                    List.append model.pages pages

                enableDownloadButton : Bool
                enableDownloadButton =
                    listingsStillBeingProcessed updatedListings |> not
            in
            ( { model
                | listings = updatedListings
                , pages = newPagesContents
                , enableDownloadButton = enableDownloadButton
              }
            , Cmd.none
            )

        CouldNotGetPagesOfListing listingId ->
            let
                updatedListings : List Listing
                updatedListings =
                    List.map
                        (\l ->
                            if l.id == listingId then
                                { l | pagesContentsRetrievalStatus = Error }

                            else
                                l
                        )
                        model.listings
            in
            ( { model | listings = updatedListings }, Cmd.none )


encodeListingForPagesContentsExtraction : Listing -> Encode.Value
encodeListingForPagesContentsExtraction l =
    Encode.object
        [ ( "id", Encode.int l.id )
        , ( "fileContents", Encode.string l.fileContents )
        ]


listingsStillBeingProcessed : List Listing -> Bool
listingsStillBeingProcessed listings =
    listingsPagesStillBeingCounted listings && listingsPagesStillBeingRendered listings


listingsPagesStillBeingRendered : List Listing -> Bool
listingsPagesStillBeingRendered listings =
    listings
        |> List.map .pagesContentsRetrievalStatus
        |> List.member Processing


listingsPagesStillBeingCounted : List Listing -> Bool
listingsPagesStillBeingCounted listings =
    listings
        |> List.map .numberOfPages
        |> List.member Counting


makeTheInnerPages : List Listing -> Pages -> String
makeTheInnerPages listings pages =
    let
        listingsPages : List String
        listingsPages =
            listings
                |> calculatePageNumbers 0
                |> List.map (\l -> renderThisListingsPages l pages)
    in
    listingsPages
        |> String.join ""


renderThisListingsPages : Listing -> Pages -> String
renderThisListingsPages listing pages =
    let
        thisListingsPages : Pages
        thisListingsPages =
            List.filter (\p -> p.listingId == listing.id) pages
    in
    renderPages thisListingsPages "" listing.startingPageNumber


renderPages : Pages -> String -> Int -> String
renderPages pagesToRender renderedPages thisPagesNumber =
    case pagesToRender of
        head :: tail ->
            renderPages
                tail
                (renderedPages ++ renderPage head thisPagesNumber)
                (thisPagesNumber + 1)

        [] ->
            renderedPages


renderPage : Page -> Int -> String
renderPage page pageNumber =
    let
        -- The units used in Word is dxa which is 1/20th of a point. Meaning, there are 20 dxas in 1 pt.
        --  1 cm = 28.3465 pts
        --  1 cm = 28.3464566929px @72px/inch
        --  1 pt = 1.333 pixels
        --  Unit converter: https://unit-converter.kurylk.in
        maxHeight : Float
        maxHeight =
            -- In pts
            --  297 mm is 841.89 pts. This is equivalent to 16837.79527559 twips.
            29.7 * 28.3465

        maxWidth : Float
        maxWidth =
            --  In pts
            --  210 mm is 595.276 pts. This is equivalent to 11905.511811024 twips.
            21 * 28.3456

        imageHeight : Float
        imageHeight =
            --  In pts
            Basics.toFloat page.naturalHeight / 1.333

        imageWidth : Float
        imageWidth =
            --  In pts
            Basics.toFloat page.naturalWidth / 1.333

        ( finalHeight, finalWidth ) =
            let
                ratio =
                    Basics.min (maxHeight / imageHeight) (maxWidth / imageWidth)
            in
            ( imageHeight * ratio, imageWidth * ratio )
    in
    """
    <page header="alignment: right; format:@pageNumber">
        <p><img src="@pageContents" height="@height" width="@width"/></p>
    </page>
    """
        |> String.replace "@pageNumber" (String.fromInt pageNumber)
        |> String.replace "@height" (String.fromFloat finalHeight)
        |> String.replace "@width" (String.fromFloat finalWidth)
        |> String.replace "@pageContents" page.contents


makeAnIndex : List Listing -> String
makeAnIndex listings =
    let
        tableHeader : String
        tableHeader =
            (wrapInATag "span" "bold=\"true\"" "Serial" |> wrapInATag "cell" "width=\"10\"")
                ++ (wrapInATag "span" "bold=\"true\"" "Title" |> wrapInATag "cell" "")
                ++ (wrapInATag "span" "bold=\"true\"" "Page(s)" |> wrapInATag "cell" "width=\"20\"")
                |> wrapInATag "row" "tableHeader=\"true\""

        tableRows : String
        tableRows =
            listings
                |> calculatePageNumbers 0
                |> List.map makeAListingIndexRow
                |> String.join ""
    in
    tableHeader
        ++ tableRows
        |> wrapInATag "table" "width=\"100%\""
        |> wrapInATag "page" ""


indexRowTemplate : String
indexRowTemplate =
    (wrapInATag "span" "" "@Serial" |> wrapInATag "cell" "align=\"right\"; width=\"10\"")
        ++ (wrapInATag "span" "" "@Title" |> wrapInATag "cell" "align=\"left\"")
        ++ (wrapInATag "span" "" "@Pages" |> wrapInATag "cell" "align=\"right\"; width=\"20\"")
        |> wrapInATag "row" ""


makeAListingIndexRow : Listing -> String
makeAListingIndexRow listing =
    indexRowTemplate
        |> String.replace "@Serial" (String.fromInt listing.index)
        |> String.replace "@Title" (" " ++ listing.title)
        |> String.replace "@Pages" (getPageNumberString listing.startingPageNumber listing.endingPageNumber)


getPageNumberString : Int -> Int -> String
getPageNumberString startingPageNumber endingPageNumber =
    if startingPageNumber == endingPageNumber then
        String.fromInt startingPageNumber

    else
        String.fromInt startingPageNumber ++ " - " ++ String.fromInt endingPageNumber


wrapInATag : String -> String -> String -> String
wrapInATag tag configuration data =
    "<" ++ tag ++ " " ++ configuration ++ ">" ++ data ++ "</" ++ tag ++ ">"


removeFileExtension : String -> String
removeFileExtension filename =
    filename
        |> String.split "."
        |> (\words -> List.take (List.length words - 1) words)
        |> String.join "."


reIndexListings : List Listing -> List Listing
reIndexListings listings =
    List.map2 (\l i -> { l | index = i }) listings (List.range 1 (List.length listings))


calculatePageNumbers : Int -> List Listing -> List Listing
calculatePageNumbers lastListingsEndingPageNumber remainingListings =
    case remainingListings of
        head :: tail ->
            let
                numberOfPages : Int
                numberOfPages =
                    case head.numberOfPages of
                        Counted x ->
                            x

                        _ ->
                            0
            in
            { head | startingPageNumber = lastListingsEndingPageNumber + 1, endingPageNumber = lastListingsEndingPageNumber + numberOfPages } :: calculatePageNumbers (lastListingsEndingPageNumber + numberOfPages) tail

        [] ->
            []


encodeDetailsForPageCount : Id -> String -> Encode.Value
encodeDetailsForPageCount id urlEncodedFile =
    Encode.object
        [ ( "listingId", Encode.int id )
        , ( "url", Encode.string urlEncodedFile )
        ]


port getPageCountOfPDF : Encode.Value -> Cmd msg


port getTheImagesDimensions : Page -> Cmd msg


port getPagesOfPDFAsASetOfImages : Encode.Value -> Cmd msg


port generateADocument : Encode.Value -> Cmd msg


port testPDF : Encode.Value -> Cmd msg



--  SUBSCRIPTIONS


port gotPageCountOfPDF : (Encode.Value -> msg) -> Sub msg


port couldNotGetPageCountOfPDF : (Int -> msg) -> Sub msg


port gotImageDimensions : (Page -> msg) -> Sub msg


port gotPagesOfListing : (Encode.Value -> msg) -> Sub msg


port couldNotGetPagesOfListing : (Int -> msg) -> Sub msg


numberOfPagesInListingDecoder : Decoder NumberOfPagesInListing
numberOfPagesInListingDecoder =
    Decode.map2 NumberOfPagesInListing listingIdDecoder pageCountDecoder


listingIdDecoder : Decoder Id
listingIdDecoder =
    Decode.field "listingId" Decode.int


pageCountDecoder : Decoder Int
pageCountDecoder =
    Decode.field "pageCount" Decode.int


pageDecoder : Decoder Page
pageDecoder =
    Decode.map5 Page
        (Decode.field "listingId" Decode.int)
        (Decode.field "id" Decode.int)
        (Decode.field "contents" Decode.string)
        (Decode.field "naturalHeight" Decode.int)
        (Decode.field "naturalWidth" Decode.int)


pagesDecoder : Decoder Pages
pagesDecoder =
    Decode.list pageDecoder


decodeNumberOfPagesInListing : Decode.Value -> Msg
decodeNumberOfPagesInListing value =
    case Decode.decodeValue numberOfPagesInListingDecoder value of
        Ok numberOfPages ->
            GotNumberOfPagesInListing numberOfPages

        Err e ->
            Debug.log (Debug.toString e) NoOp


decodePagesOfListing : Decode.Value -> Msg
decodePagesOfListing value =
    case Decode.decodeValue pagesDecoder value of
        Ok pages ->
            GotPagesOfListing pages

        Err err ->
            Debug.log (Debug.toString err) NoOp


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ gotPageCountOfPDF decodeNumberOfPagesInListing
        , couldNotGetPageCountOfPDF CouldNotGetNumberOfPagesInListing
        , gotPagesOfListing decodePagesOfListing
        , couldNotGetPagesOfListing CouldNotGetPagesOfListing
        ]


main : Program Flags Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
