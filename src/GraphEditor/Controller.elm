module GraphEditor.Controller where

import Debug

import List as L

import Diagrams.Interact exposing (..)
import Diagrams.Geom exposing (..)
import Diagrams.Actions exposing (..)

import GraphEditor.Model exposing (..)
import GraphEditor.Util exposing (..)

posNodeActions nodePath dragState =
    case dragState of
      Nothing -> { emptyActionSet | mouseDown <- Just <| stopBubbling <|
                                      \(MouseEvent evt) -> DragNodeStart { nodePath = nodePath, offset = evt.offset } }
      _ -> emptyActionSet

nodeXOutActions nodePath = { emptyActionSet | click <- Just <| keepBubbling <| always <| RemoveNode nodePath }

edgeXOutActions edge = { emptyActionSet | click <- Just <| keepBubbling <| always <| RemoveEdge edge }

topLevelActions state =
    case state.dragState of
      Just (DragPanning _) ->
          { emptyActionSet | mouseMove <- Just <|
                                keepBubbling <| \(MouseEvent evt) -> DragMove evt.offset
                           , mouseUp <- Just <| stopBubbling <| always DragEnd }
      _ -> emptyActionSet

canvasActions nodePath dragState =
    case dragState of
      Nothing ->
          if nodePath == []
          then { emptyActionSet | mouseDown <- Just <|
                  stopBubbling <| \(MouseEvent evt) -> PanStart { offset = evt.offset } }
          else emptyActionSet
      Just dragging ->
          let moveAndUp = { emptyActionSet | mouseMove <- Just <|
                                                stopBubbling <| \(MouseEvent evt) -> DragMove evt.offset
                                           , mouseUp <- Just <| stopBubbling <| always DragEnd }
          in case dragging of
               DraggingNode attrs ->
                  if | attrs.nodePath `directlyUnder` nodePath -> moveAndUp 
                     | attrs.nodePath `atOrAbove` nodePath ->
                          { emptyActionSet | mouseEnter <- Just <| keepBubbling <| always <| OverLambda nodePath
                                           , mouseLeave <- Just <| keepBubbling <| always <| NotOverLambda nodePath
                                           , mouseUp <- Just <| keepBubbling <|
                                              (\(MouseEvent evt) -> DropNodeInLambda { lambdaPath = nodePath
                                                                                     , droppedNodePath = attrs.nodePath
                                                                                     , posInLambda = evt.offset }) }
                     | otherwise -> emptyActionSet
               DraggingEdge attrs ->
                  if nodePath == [] then moveAndUp else emptyActionSet
               _ -> emptyActionSet

atOrAbove xs ys = (xs /= ys) && (L.length xs <= L.length ys)

directlyUnder xs ys = L.length xs - 1 == L.length ys

-- TODO: check state
outPortActions : State -> OutPortId -> ActionSet Tag Action
outPortActions state portId =
    if outPortState state portId == NormalPort
    then { emptyActionSet | mouseDown <- Just <| stopBubbling <|
              (\evt -> case mousePosAtPath evt [TopLevel, Canvas] of
                         Just pos -> DragEdgeStart { fromPort = portId, endPos = pos }
                         Nothing -> Debug.crash "mouse pos not found derp") }
    else emptyActionSet

inPortActions : State -> InPortId -> ActionSet Tag Action
inPortActions state portId =
    let portState = inPortState state portId
    in case state.dragState of
         Just (DraggingEdge attrs) -> if portState == ValidPort
                                      then { emptyActionSet | mouseUp <- Just <| stopBubbling
                                                <| always <| AddEdge { from = attrs.fromPort, to = portId } }
                                      else emptyActionSet
         _ -> emptyActionSet

-- process 'em...

update : UpdateFunc State Action
update action state =
    case action of
      -- dragging
      DragNodeStart attrs -> { state | dragState <- Just <| DraggingNode { attrs | overLambdaNode = Nothing } }
      DragEdgeStart attrs -> { state | dragState <- Just <|
          DraggingEdge { attrs | upstreamNodes = upstreamNodes state.graph (fst attrs.fromPort) } }
      PanStart {offset} -> { state | dragState <- Just <| DragPanning { offset = offset } }
      DragMove mousePos ->
          case state.dragState of
            Just (DraggingNode attrs) ->
                let moveRes = moveNode state.graph attrs.nodePath
                                       (mousePos `pointSubtract` attrs.offset)
                in case moveRes of
                     Ok newGraph -> { state | graph <- newGraph }
                     Err msg -> Debug.crash msg
            Just (DraggingEdge attrs) ->
                { state | dragState <-
                            Just <| DraggingEdge { attrs | endPos <- mousePos } }
            Just (DragPanning {offset}) ->
                { state | pan <- mousePos `pointSubtract` offset }
            Nothing -> state
            _ -> state
      DragEnd -> { state | dragState <- Nothing }
      -- add and remove
      AddNode posNode ->
          case addNode [posNode.id] posNode state.graph of
            Ok newGraph -> { state | graph <- newGraph }
            Err msg -> Debug.crash msg
      RemoveNode nodePath ->
          case removeNode state.graph nodePath of
            Ok newGraph -> { state | graph <- newGraph }
            Err msg -> Debug.crash msg
      AddEdge edge ->
          case addEdge edge state.graph of
            Ok newGraph -> { state | graph <- newGraph
                                   , dragState <- Nothing }
            Err msg -> Debug.crash msg
      RemoveEdge edge -> { state | graph <- removeEdge edge state.graph }
      -- drag into lambdas
      OverLambda lambdaPath ->
          case state.dragState of
            Just (DraggingNode attrs) ->
                let ds = state.dragState
                in { state | dragState <- Just <| DraggingNode { attrs | overLambdaNode <- Just lambdaPath } }
            _ -> Debug.crash "unexpected event"
      NotOverLambda lambdaPath ->
          case state.dragState of
            Just (DraggingNode attrs) ->
                let ds = state.dragState
                in { state | dragState <- Just <| DraggingNode { attrs | overLambdaNode <- Nothing } }
            _ -> Debug.crash "unexpected event"
      DropNodeInLambda {lambdaPath, droppedNodePath, posInLambda} ->
          if canBeDroppedInLambda state.graph lambdaPath droppedNodePath
          then case moveNodeToLambda state.graph lambdaPath droppedNodePath posInLambda of
            Ok newGraph -> { state | graph <- newGraph }
            Err msg -> Debug.crash msg
          else state