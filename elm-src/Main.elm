module Main exposing (..)
import List
import Dict
import String
import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode
import Json.Decode as Decode
import Json.Encode as Encode
import Json.Decode exposing (Decoder, map2, map3, map4, map5, field, list, dict, string, int)


-- Types

type alias SearchResult =
    { query : String
    , page_num : Int
    , page_size : Int
    , results : List Artifact
    }


type alias Artifact =
    { name : String
    , version : String
    , spec : ArtifactSpec
    }


type alias ArtifactSpec =
    { path : String
    , pkg : String
    , channel : String
    , arch : String
    , name : String
    }


type alias Model =
    { error : Maybe Http.Error
    , query : String
    , page_num : Int
    , response : Maybe SearchResult
    }


initialModel : Model
initialModel =
    { error = Nothing
    , query = ""
    , page_num = 1
    , response = Nothing
    }


type Msg
    = NoOp
    | SubmitForm
    | UpdatePageNum Int
    | SetField FormField String
    | Response (Result Http.Error SearchResult)


type FormField
    = Query


-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case Debug.log "msg" msg of
        NoOp ->
            ( model, Cmd.none )

        SubmitForm ->
            ( { model | error = Nothing, response = Nothing }
            , getQuery model.query model.page_num
            )

        UpdatePageNum value ->
            ( { model | page_num = value, error = Nothing, response = Nothing }
            , getQuery model.query value
            )

        SetField field value ->
            ( setField field value model, Cmd.none )

        Response (Ok response) ->
            ( { model | error = Nothing, response = Just response }, Cmd.none )

        Response (Err error) ->
            ( { model | error = Just error, response = Nothing }, Cmd.none )



-- HTTP

getQuery : String -> Int -> Cmd Msg
getQuery query page_num =
  Http.get
    { url = "http://localhost:8888/search?query=" ++ query ++ "&page_num=" ++ (String.fromInt page_num)
    , expect = Http.expectJson Response searchQueryDecoder
    }


searchQueryDecoder: Decoder SearchResult
searchQueryDecoder =
    map4 SearchResult
        (field "query" string)
        (field "page_num" int)
        (field "page_size" int)
        (field "results" (list artifactDecoder))


artifactDecoder : Decoder Artifact
artifactDecoder =
    map3 Artifact
        (field "name" string)
        (field "version" string)
        (field "spec" artifactSpecDecoder)


artifactSpecDecoder : Decoder ArtifactSpec
artifactSpecDecoder =
    map5 ArtifactSpec
        (field "path" string)
        (field "pkg" string)
        (field "channel" string)
        (field "arch" string)
        (field "name" string)



-- HELPERS


setField : FormField -> String -> Model -> Model
setField field value model =
    case field of
        Query ->
            { model | query = value }



onEnter : msg -> Attribute msg
onEnter msg =
    keyCode
        |> Decode.andThen
            (\key ->
                if key == 13 then
                    Decode.succeed msg
                else
                    Decode.fail "Not enter"
            )
        |> on "keyup"



-- VIEWS

viewArtifact : Artifact -> Html Msg
viewArtifact artifact =
    li []
        [ b [] [text (artifact.name ++ " v" ++ artifact.version)]
        , br [] []
        , text ("artifact: ")
        , i [] [text (artifact.spec.path)]
        ]


viewPageBar : SearchResult -> Html Msg
viewPageBar response =
    button
        [ onClick (UpdatePageNum (response.page_num + 1)) ]
        [ text (String.fromInt (response.page_num + 1)) ]


viewResponse : SearchResult -> Html Msg
viewResponse response =
    div [ class "response-container" ]
        [ h2 [] [ text "Results" ]
        , div []
            [ text response.query ]
        , ol [start ((response.page_num - 1) * response.page_size + 1)]
            ((List.map viewArtifact) response.results)
        , div []
            [ text (String.fromInt response.page_num) ]
        , div []
            [ text (String.fromInt response.page_size) ]
        , viewPageBar response
        ]


viewError : Http.Error -> Html Msg
viewError error =
    div [ class "error-container" ]
        [ h2 [] [ text "Search Errors" ]
        , div [] (case error of
            Http.BadUrl url ->
                [ text ("Bad URL: " ++ url)]
            Http.Timeout ->
                [ text "Network timeout" ]
            Http.NetworkError ->
                [ text "Network error" ]
            Http.BadStatus code ->
                [ text ("Bad status: " ++ String.fromInt code) ]
            Http.BadBody body ->
                [ text body ]
        )
        ]


viewUtils :
    { a | error : Maybe Http.Error, response : Maybe SearchResult }
    -> ({ a | error : Maybe Http.Error, response : Maybe SearchResult } -> Html Msg)
    -> Html Msg
viewUtils model viewF =
    div []
        [ viewHeader
        , viewF model
        , case model.response of
            Just response ->
                viewResponse response

            Nothing ->
                text ""
        , case model.error of
            Just error ->
                viewError error

            Nothing ->
                text ""
        , viewFooter
        ]


viewHeader : Html msg
viewHeader =
    div [ class "header" ]
        [ h1 [] [ text ("Conda-Forge") ]
        ]

viewFooter : Html msg
viewFooter =
    div [ class "footer" ]
        [ a [ href "https://github.com/lucamug/elm-form-examples" ]
            [ text "[ code ] " ]
        , a [ href "https://medium.com/@l.mugnaini/forms-in-elm-validation-tutorial-and-examples-2339830055da" ] [ text " [ article ]" ]
        ]

view : Model -> Html Msg
view model =
    viewUtils model viewForm


viewForm : Model -> Html Msg
viewForm model =
    Html.div
        [ class "form-container"
        , onEnter SubmitForm
        ]
        [ label []
            [ text "Search: "
            , input
                [ type_ "text"
                , placeholder "Query"
                , onInput <| SetField Query
                , value model.query
                ]
                []
            ]
        , button
            [ onClick SubmitForm ]
            [ text "Submit" ]
        ]


-- MAIN

main : Program Decode.Value Model Msg
main =
  Browser.element
        { init = \_ -> ( initialModel, Cmd.none )
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }
