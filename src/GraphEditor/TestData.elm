module GraphEditor.TestData where

import GraphEditor.Model exposing (..)

import Dict as D
import List as L
import Result as R

import Debug

fooNode = ApNode { title = "Foo", params = ["InAasdfasdfsdafasdfs", "asdfs", "InB", "InC"], results = ["out1", "out2"] }
fooPosNode = { node = fooNode, pos = (-300, 100), id = "foo" }

bazNode = ApNode { title = "Baz", params = ["InA", "InB", "InC"], results = ["out1", "out2"] }
bazPosNode = { node = bazNode, pos = (100, -200), id = "baz" }

barNode = ApNode { title = "Bar", params = ["InA", "InB", "InC"], results = ["out1", "out2"] }
barPosNode = { node = barNode, pos = (100, 100), id = "bar" }

lambdaFooEdge = { from = (["lambda0"], FuncValueSlot), to = (["foo"], ApParamSlot "InC") }
fooBarEdge = { from = (["foo"], ApResultSlot "out1"), to = (["bar"], ApParamSlot "InA") }
barBazEdge = { from = (["bar"], ApResultSlot "out1"), to = (["baz"], ApParamSlot "InA") }
bazIfEdge = { from = (["baz"], ApResultSlot "out1"), to = (["if1"], IfCondSlot) }

subBazNode = ApNode { title = "SubBaz", params = ["InA", "InB", "InC"], results = ["out1", "out2"] }
subBazPosNode = { node = subBazNode, pos = (-50, -50), id = "baz1" }

subBarNode = ApNode { title = "SubBar", params = ["InA", "InB", "InC"], results = ["out1", "out2"] }
subBarPosNode = { node = subBarNode, pos = (50, 50), id = "bar1" }

subBarSubBazEdge = { from = (["lambda0", "bar1"], ApResultSlot "out1"), to = (["lambda0", "baz1"], ApParamSlot "InA") }

lambdaNode =
    LambdaNode
      { nodes = (D.fromList [ (subBarPosNode.id, subBarPosNode), (subBazPosNode.id, subBazPosNode) ])
      , dims = { width = 300, height = 200 }
      }
lambdaPosNode = { node = lambdaNode, pos = (-450, -100), id = "lambda0" }

ifNode = IfNode
ifPosNode = { id = "if1", node = ifNode, pos = (-200, 300) }

nodes = [lambdaPosNode, fooPosNode, bazPosNode, barPosNode, ifPosNode]
edges = [fooBarEdge, barBazEdge, subBarSubBazEdge, lambdaFooEdge, bazIfEdge]

initGraph : Graph
initGraph = let withNodes : Result String Graph
                withNodes = L.foldl (\posNode graphRes -> graphRes `R.andThen` (addNode [posNode.id] posNode))
                                    (Ok emptyGraph) nodes
                withEdges : Result String Graph
                withEdges = L.foldl (\edge graphRes -> graphRes `R.andThen` (addEdge edge))
                                    withNodes edges
            in case withEdges of
                 Ok graph -> graph
                 Err msg -> Debug.crash msg

initState : State
initState = { emptyState | graph <- initGraph }