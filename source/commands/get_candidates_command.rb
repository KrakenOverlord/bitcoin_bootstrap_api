# Returns a JSON hash that looks like this:
#
#     {
#       'candidates' : [<contributor hash>]
#     }
#
#  OR
#
#     {
#       'error' => <true, false>,
#       'error_code' : <integer>
#     }
#
# Error Codes:
#   100 - internal server error.
#
# POST /api?command=GetCandidates
module Commands
  class GetCandidatesCommand
    def execute(args)
      { 'candidates' => $database.get_candidates(false) }
    end
  end
end
