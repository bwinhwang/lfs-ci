#!/bin/bash

## @file    try.sh
#  @brief   a try-catch-implementation for bash
#  @details source: https://stackoverflow.com/questions/22009364/is-there-a-try-catch-command-in-bash
#  
#  example:
#  try
#  (
#     your code, which can fail
#  )
#  catch
#  (
#     your code
#  )
#

## @fn      try()
#  @brief   try-catch implementation
#  @param   <none>
#  @return  <none>
function try()
{
    [[ $- = *e* ]]; SAVED_OPT_E=$?
    set +e
}

## @fn      throw()
#  @brief   try-catch implementation
#  @param   <none>
#  @return  <none>
function throw()
{
    exit $1
}

## @fn      catch()
#  @brief   try-catch implementation
#  @param   <none>
#  @return  <none>
function catch()
{
    export ex_code=$?
    (( $SAVED_OPT_E )) && set +e
    return $ex_code
}

## @fn      throwErrors()
#  @brief   try-catch implementation
#  @param   <none>
#  @return  <none>
function throwErrors()
{
    set -e
}

## @fn      ignoreErrors()
#  @brief   try-catch implementation
#  @param   <none>
#  @return  <none>
function ignoreErrors()
{
    set +e
}

