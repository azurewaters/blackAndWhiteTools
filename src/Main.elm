port module Main exposing (main)

import Browser
import File exposing (File)
import Html exposing (Attribute, Html, a, button, div, h1, img, p, text)
import Html.Attributes exposing (class, classList, disabled, draggable, id, src, style)
import Html.Events exposing (on, onClick, preventDefaultOn)
import Html.Keyed as Keyed
import Json.Decode as Decode exposing (Decoder, Error(..), value)
import Json.Encode as Encode



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
    , id : Id --  Zero based
    , naturalHeight : Int
    , naturalWidth : Int
    }


type alias Pages =
    List Page


type alias NumberOfPagesInListing =
    { listingId : Int
    , pageCount : Int
    }


type alias Listing =
    { id : Id
    , file : Encode.Value
    , index : Index
    , title : String
    , numberOfPages : PageCount
    , startingPageNumber : Int
    , endingPageNumber : Int
    }


type alias Listings =
    List Listing


type alias Model =
    { currentScreen : CurrentScreen
    , listings : Listings
    , pages : Pages
    , lastListingsId : Int --  lastListingsId used in calculating page numbers
    , listingBeingDragged : Maybe Listing
    }


type alias Flags =
    {}


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { currentScreen = Home
      , listings = []
      , pages = []
      , lastListingsId = 0
      , listingBeingDragged = Nothing
      }
    , Cmd.none
    )



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Pocketful of Sunshine - Nice, niche tools"
    , body = [ viewRoot model ]
    }


viewRoot : Model -> Html Msg
viewRoot model =
    div
        [ class "h-screen w-full grid grid-cols-1 content-start space-y-8 p-8"
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
    div [ class "grid grid-flow-col w-max gap-2 items-center" ]
        [ img [ src "assets/logo.png", class "h-6" ] []
        , div [ class "font-bold text-xl text-black pr-4" ] [ text "Pocketful of Sunshine" ]
        , navigationLink HomeLinkClicked (currentPage == Home) "Home"
        , navigationLink IndexMakerLinkClicked (currentPage == IndexMaker) "Index Maker"
        ]


navigationLink : Msg -> Bool -> String -> Html Msg
navigationLink msg show linkText =
    a
        [ onClick msg
        , class "cursor-pointer"
        , classList [ ( "font-semibold", show ), ( "text-black", show ) ]
        ]
        [ text linkText ]


pageFooter : Html Msg
pageFooter =
    div [ class "w-full flex justify-center text-xs text-gray-300 pt-4 pb-4" ]
        [ text "Copyright © 2022 Pocketful of Sunshine. All rights reserved. Terms and Conditions Apply"
        ]


home : Html Msg
home =
    div []
        [ h1 [] [ text "What is Pocketful of Sunshine?" ]
        , p [] [ text "Pocketful of Sunshine is a home for tiny, niche tools. Maybe they'll be of use to you, or maybe to someone you know?" ]
        , h1 [] [ text "What is an Index Maker?" ]
        , p [] [ text "The Index Maker is Drag in a bunch of PDFs or images (maybe screenshots or photographs) and the Index Maker will put these together into a single PDF and number all the pages. It'll also create a contents page. Best way to understand what it does is to take it for a spin!" ]
        , h1 [] [ text "Does any of this cost anything?" ]
        , p [] [ text "Nope. Use it to your heart's content. Tell your friends about it." ]
        ]


indexMaker : Model -> Html Msg
indexMaker model =
    let
        disable : Bool
        disable =
            canDownloadButtonBeEnabled model.listings |> not
    in
    div
        [ class "min-h-full max-h-full grid grid-flow-row gap-4"
        , style "grid-template-rows" "1fr min-content"
        ]
        [ Keyed.node "div"
            [ classList
                [ ( "min-h-full overflow-y-auto w-full grid grid-cols-1 gap-2", True )
                , ( "content-center", List.length model.listings == 0 )
                , ( "content-start justify-center", List.length model.listings > 0 )
                ]
            , onFilesDrop FilesDropped
            , onDragOver NoOp
            ]
            (if List.length model.listings == 0 then
                [ ( "empty"
                  , div
                        [ class "text-gray-400 mx-auto" ]
                        [ text "Drag your PDFs, JPEGs and PNGs here." ]
                  )
                ]

             else
                List.map (\l -> ( l.id |> String.fromInt, listItem l )) model.listings
            )
        , div
            [ class "grid grid-flow-col auto-cols-max justify-between gap-x-4 mt-4" ]
            [ button
                [ onClick ClearAllButtonClicked
                , disabled (List.length model.listings == 0)
                ]
                [ text "Clear all" ]
            , button
                [ onClick DownloadDocumentButtonClicked
                , disabled disable
                ]
                [ text "Download" ]
            ]
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


onFilesDrop : (List Encode.Value -> Msg) -> Attribute Msg
onFilesDrop msg =
    preventDefaultOn "drop" (Decode.map2 Tuple.pair (Decode.map msg filesDecoder) (Decode.succeed True))


filesDecoder : Decoder (List Encode.Value)
filesDecoder =
    Decode.at [ "dataTransfer", "files" ] (Decode.list Decode.value)


onDragEnd : Msg -> Attribute Msg
onDragEnd msg =
    on "dragend" (Decode.succeed msg)


listItem : Listing -> Html Msg
listItem listing =
    div
        [ class "group w-full p-4 border border-gray-300 rounded-md grid gap-4 text-sm bg-gray-50 hover:bg-transparent"
        , style "grid-template-columns" "1fr minmax(10px, min-content)"
        , onDragStart (ListingDragStart listing)
        , onDragOver NoOp
        , onDrop (ListingDrop listing)
        , onDragEnd ListingDragEnd
        , draggable "true"
        ]
        [ div
            [ class "max-h-full w-full grid gap-2"
            , style "grid-template-rows" "1fr min-content"
            ]
            [ div [ class "overflow-auto max-w-full max-h-6" ] [ listing.title |> text ]
            , div [ class "text-xs text-gray-400" ]
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
        , div
            [ class "cursor-pointer text-gray-500 rotate-45 invisible group-hover:visible"
            , onClick (ListItemsDeleteButtonClicked listing.id)
            ]
            [ text "+" ]
        ]



-- UPDATE


type Msg
    = NoOp
    | HomeLinkClicked
    | IndexMakerLinkClicked
    | FilesDropped (List Encode.Value)
    | ListItemsDeleteButtonClicked Id
    | ListingDragStart Listing
    | ListingDrop Listing
    | ListingDragEnd
    | GotNumberOfPagesInListing NumberOfPagesInListing
    | CouldNotGetNumberOfPagesInListing Id
    | ClearAllButtonClicked
    | DownloadDocumentButtonClicked


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
                admissibleFiles : List Encode.Value
                admissibleFiles =
                    files
                        |> List.filter
                            (\file ->
                                case decodeFile file of
                                    Just f ->
                                        List.member (File.mime f) [ "image/png", "image/jpeg", "application/pdf" ]

                                    Nothing ->
                                        False
                            )

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

                newListings : Listings
                newListings =
                    List.map3
                        (\value id index ->
                            let
                                ( t, nOP ) =
                                    case decodeFile value of
                                        Just f ->
                                            ( f |> File.name |> removeFileExtension
                                            , case File.mime f of
                                                "application/pdf" ->
                                                    Counting

                                                _ ->
                                                    Counted 1
                                            )

                                        Nothing ->
                                            ( "", Unvailable )
                            in
                            { id = id
                            , file = value
                            , index = index
                            , title = t
                            , numberOfPages = nOP
                            , startingPageNumber = 0
                            , endingPageNumber = 0
                            }
                        )
                        admissibleFiles
                        newIds
                        newIndexes

                newPages : Pages
                newPages =
                    List.filterMap
                        (\l ->
                            Maybe.andThen
                                (\f ->
                                    if File.mime f /= "application/pdf" then
                                        Page l.id 0 0 0 |> Just

                                    else
                                        Nothing
                                )
                                (decodeFile l.file)
                        )
                        newListings

                newCommands : List (Cmd Msg)
                newCommands =
                    List.map
                        (\l ->
                            case l.numberOfPages of
                                Counting ->
                                    encodeListingIdAndFile l.id l.file |> getThePageCountOfThePDF

                                _ ->
                                    Cmd.none
                        )
                        newListings
            in
            ( { model
                | listings = List.append model.listings newListings
                , lastListingsId = model.lastListingsId + List.length newListings
                , pages = model.pages ++ newPages
              }
            , Cmd.batch newCommands
            )

        ListItemsDeleteButtonClicked id ->
            let
                updatedListings : Listings
                updatedListings =
                    List.filter (\l -> l.id == id |> not) model.listings

                updatedPages : Pages
                updatedPages =
                    List.filter (\p -> p.listingId /= id) model.pages
            in
            ( { model
                | listings = reIndexListings updatedListings
                , pages = updatedPages
              }
            , Cmd.none
            )

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

                newListings : Listings
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

        GotNumberOfPagesInListing numberOfPagesInListing ->
            let
                updatedListings : Listings
                updatedListings =
                    List.map
                        (\l ->
                            if l.id == numberOfPagesInListing.listingId then
                                { l
                                    | numberOfPages = Counted numberOfPagesInListing.pageCount
                                }

                            else
                                l
                        )
                        model.listings

                --  Since it's a bunch of PDF pages, they'll occupy the maximum space allowed
                --  And, we know the number of pages, so we'll just create the pages
                newPages : Pages
                newPages =
                    updatedListings
                        |> List.filter (\l -> l.id == numberOfPagesInListing.listingId)
                        |> List.head
                        |> (\maybeListing ->
                                case maybeListing of
                                    Just l ->
                                        createPagesForPDF l

                                    Nothing ->
                                        []
                           )
            in
            ( { model | listings = updatedListings, pages = model.pages ++ newPages }, Cmd.none )

        CouldNotGetNumberOfPagesInListing listingId ->
            let
                updatedListings : Listings
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
            ( { model | listings = updatedListings }, Cmd.none )

        ClearAllButtonClicked ->
            ( { model
                | listings = []
                , pages = []
              }
            , Cmd.none
            )

        DownloadDocumentButtonClicked ->
            let
                dataToSendOut : Encode.Value
                dataToSendOut =
                    Encode.object
                        [ ( "listings", encodeListings model.listings )
                        , ( "pages", encodePages model.pages )
                        ]
            in
            ( model, generateADocument dataToSendOut )


createPagesForPDF : Listing -> Pages
createPagesForPDF listing =
    case listing.numberOfPages of
        Counted n ->
            List.range 0 (n - 1)
                |> List.map (\pageId -> Page listing.id pageId (29.7 * 28.3465 |> Basics.round) (21 * 28.3456 |> Basics.round))

        _ ->
            []


encodePages : Pages -> Encode.Value
encodePages pages =
    Encode.list pageEncoder pages


pageEncoder : Page -> Encode.Value
pageEncoder page =
    Encode.object
        [ ( "listingId", Encode.int page.listingId )
        , ( "id", Encode.int page.id )
        , ( "naturalHeight", Encode.int page.naturalHeight )
        , ( "naturalWidth", Encode.int page.naturalWidth )
        ]


encodeListings : Listings -> Encode.Value
encodeListings listings =
    Encode.list encodeListing listings


encodeListing : Listing -> Encode.Value
encodeListing listing =
    Encode.object
        [ ( "id", Encode.int listing.id )
        , ( "file", listing.file )
        , ( "index", Encode.int listing.index )
        , ( "title", Encode.string listing.title )
        , ( "numberOfPages"
          , (case listing.numberOfPages of
                Counted x ->
                    x

                _ ->
                    -1
            )
                |> Encode.int
          )
        , ( "startingPageNumber", Encode.int listing.startingPageNumber )
        , ( "endingPageNumber", Encode.int listing.endingPageNumber )
        ]


decodeFile : Encode.Value -> Maybe File
decodeFile value =
    case Decode.decodeValue File.decoder value of
        Ok f ->
            Just f

        Err _ ->
            Nothing


canDownloadButtonBeEnabled : Listings -> Bool
canDownloadButtonBeEnabled listings =
    List.length listings > 0 && not (listingsPagesStillBeingCounted listings)


listingsPagesStillBeingCounted : Listings -> Bool
listingsPagesStillBeingCounted listings =
    listings
        |> List.map .numberOfPages
        |> List.member Counting


removeFileExtension : String -> String
removeFileExtension filename =
    filename
        |> String.split "."
        |> (\words -> List.take (List.length words - 1) words)
        |> String.join "."


reIndexListings : Listings -> Listings
reIndexListings listings =
    List.map2 (\l i -> { l | index = i }) listings (List.range 1 (List.length listings))


encodeListingIdAndFile : Id -> Encode.Value -> Encode.Value
encodeListingIdAndFile id file =
    Encode.object
        [ ( "id", Encode.int id )
        , ( "file", file )
        ]


port getThePageCountOfThePDF : Encode.Value -> Cmd msg


port generateADocument : Encode.Value -> Cmd msg



--  SUBSCRIPTIONS


port gotPageCountOfPDF : (Encode.Value -> msg) -> Sub msg


port couldNotGetPageCountOfPDF : (Int -> msg) -> Sub msg


numberOfPagesInListingDecoder : Decoder NumberOfPagesInListing
numberOfPagesInListingDecoder =
    Decode.map2 NumberOfPagesInListing listingIdDecoder pageCountDecoder


listingIdDecoder : Decoder Id
listingIdDecoder =
    Decode.field "listingId" Decode.int


pageCountDecoder : Decoder Int
pageCountDecoder =
    Decode.field "pageCount" Decode.int


decodeNumberOfPagesInListing : Decode.Value -> Msg
decodeNumberOfPagesInListing value =
    case Decode.decodeValue numberOfPagesInListingDecoder value of
        Ok numberOfPages ->
            GotNumberOfPagesInListing numberOfPages

        Err _ ->
            NoOp


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ gotPageCountOfPDF decodeNumberOfPagesInListing
        , couldNotGetPageCountOfPDF CouldNotGetNumberOfPagesInListing
        ]


main : Program Flags Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
